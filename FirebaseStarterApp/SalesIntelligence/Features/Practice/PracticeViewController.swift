import AVFoundation
import UIKit

final class PracticeViewController: UIViewController {
    private enum State {
        case idle
        case preparing
        case recording
        case uploading
        case error
    }

    private let appState = AppState.shared
    private let recordManager = RecordAndCallManager()

    private var state: State = .idle {
        didSet { updateUIForState() }
    }

    private var statusMessage: String = "Tap Start Practice to begin." {
        didSet { statusLabel.text = statusMessage }
    }

    private var sessionTask: Task<Void, Never>?
    private var timer: Timer?
    private var recordingStartDate: Date?

    private let contentStack = UIStackView()
    private let previewView = UIView()
    private let timerLabel = UILabel()
    private let statusLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private var currentUserId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Practice"
        view.backgroundColor = .systemBackground
        configureLayout()
        updateUIForState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recordManager.updatePreviewLayout(in: previewView)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            cancelOngoingSession()
        }
    }

    deinit {
        cancelOngoingSession()
    }

    private func configureLayout() {
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        previewView.backgroundColor = .black
        previewView.layer.cornerRadius = 16
        previewView.layer.masksToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 4.0 / 3.0).isActive = true

        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        timerLabel.textAlignment = .center
        timerLabel.text = "00:00"

        statusLabel.font = UIFont.preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = statusMessage

        primaryButton.setTitle("Start Practice", for: .normal)
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        primaryButton.backgroundColor = .systemGreen
        primaryButton.layer.cornerRadius = 12
        primaryButton.layer.masksToBounds = true
        primaryButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        primaryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        primaryButton.addTarget(self, action: #selector(handlePrimaryButtonTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(previewView)
        contentStack.addArrangedSubview(timerLabel)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(primaryButton)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    @objc private func handlePrimaryButtonTapped() {
        switch state {
        case .idle, .error:
            startPracticeSession()
        case .recording:
            finishPracticeSession()
        case .preparing, .uploading:
            break
        }
    }

    private func startPracticeSession() {
        guard state == .idle || state == .error else { return }
        guard NetworkMonitor.shared.isConnected else {
            statusMessage = "Offline. Connect to the internet to start a practice session."
            state = .error
            return
        }
        guard let userId = appState.userId else {
            statusMessage = "Complete onboarding to begin practicing."
            state = .error
            return
        }

        currentUserId = userId

        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.sessionTask = nil
                }
            }
            await MainActor.run {
                self.state = .preparing
                self.statusMessage = "Preparing session…"
            }
            do {
                try Task.checkCancellation()
                try await self.recordManager.start(on: self.previewView)
                try Task.checkCancellation()
                try await ElevenLabsService.shared.startSession(agentID: Constants.ElevenLabs.agentID, userId: userId)
                await MainActor.run {
                    self.recordingStartDate = Date()
                    self.startTimer()
                    self.state = .recording
                    self.statusMessage = "Recording…"
                }
            } catch {
                await ElevenLabsService.shared.stopSession()
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    self.stopTimer()
                    self.state = .error
                    self.statusMessage = error.displayMessage
                    self.currentUserId = nil
                }
            }
        }
    }

    private func finishPracticeSession() {
        guard state == .recording else { return }
        guard let userId = currentUserId ?? appState.userId else {
            statusMessage = "User profile missing. Restart the session after completing onboarding."
            state = .error
            return
        }

        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.sessionTask = nil
                }
            }
            await MainActor.run {
                self.state = .uploading
                self.statusMessage = "Uploading session…"
            }
            var recordedFileURL: URL?
            do {
                try Task.checkCancellation()
                let (fileURL, duration) = try await self.recordManager.stop()
                recordedFileURL = fileURL
                await ElevenLabsService.shared.stopSession()
                await MainActor.run {
                    self.stopTimer()
                }

                let preview = try await NetworkClient.shared.uploadVideo(fileURL: fileURL,
                                                                         userId: userId,
                                                                         duration: duration)
                try? FileManager.default.removeItem(at: fileURL)

                await MainActor.run {
                    self.appState.addConversation(preview)
                    self.appState.errorMessage = nil
                    self.resetSessionState()
                    self.statusMessage = "Upload complete! Review your insights on the Home tab."
                    self.state = .idle
                }
            } catch {
                await ElevenLabsService.shared.stopSession()
                if let recordedFileURL, FileManager.default.fileExists(atPath: recordedFileURL.path) {
                    try? FileManager.default.removeItem(at: recordedFileURL)
                }
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    self.stopTimer()
                    self.state = .error
                    self.statusMessage = error.displayMessage
                    self.currentUserId = nil
                }
            }
        }
    }

    private func updateUIForState() {
        switch state {
        case .idle:
            applyPrimaryButtonStyle(title: "Start Practice",
                                    enabled: true,
                                    backgroundColor: .systemGreen)
        case .preparing:
            applyPrimaryButtonStyle(title: "Preparing…",
                                    enabled: false,
                                    backgroundColor: .systemGray3)
        case .recording:
            applyPrimaryButtonStyle(title: "End Session",
                                    enabled: true,
                                    backgroundColor: .systemRed)
        case .uploading:
            applyPrimaryButtonStyle(title: "Uploading…",
                                    enabled: false,
                                    backgroundColor: .systemGray3)
        case .error:
            applyPrimaryButtonStyle(title: "Retry Practice",
                                    enabled: true,
                                    backgroundColor: .systemOrange)
        }
    }

    private func applyPrimaryButtonStyle(title: String, enabled: Bool, backgroundColor: UIColor) {
        primaryButton.setTitle(title, for: .normal)
        primaryButton.isEnabled = enabled
        primaryButton.backgroundColor = backgroundColor
        primaryButton.alpha = enabled ? 1.0 : 0.6
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerLabel()
        }
        RunLoop.main.add(timer!, forMode: .common)
        updateTimerLabel()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStartDate = nil
        timerLabel.text = "00:00"
    }

    private func updateTimerLabel() {
        guard let start = recordingStartDate else {
            timerLabel.text = "00:00"
            return
        }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func resetSessionState() {
        recordingStartDate = nil
        timerLabel.text = "00:00"
        currentUserId = nil
    }

    private func cancelOngoingSession() {
        sessionTask?.cancel()
        sessionTask = nil
        if state == .recording || state == .preparing {
            Task { [weak self] in
                guard let self else { return }
                await self.recordManager.cancelRecording()
                await ElevenLabsService.shared.stopSession()
            }
        }
        stopTimer()
        resetSessionState()
        statusMessage = "Session cancelled."
        state = .idle
    }
}
