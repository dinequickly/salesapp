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
    private let buttonStack = UIStackView()
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

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

        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually

        startButton.setTitle("Start Practice", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        startButton.backgroundColor = .systemGreen
        startButton.layer.cornerRadius = 12
        startButton.layer.masksToBounds = true
        startButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        startButton.addTarget(self, action: #selector(handleStartTapped), for: .touchUpInside)

        stopButton.setTitle("End Session", for: .normal)
        stopButton.setTitleColor(.systemRed, for: .normal)
        stopButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        stopButton.backgroundColor = .clear
        stopButton.layer.cornerRadius = 12
        stopButton.layer.borderColor = UIColor.systemRed.cgColor
        stopButton.layer.borderWidth = 1
        stopButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        stopButton.addTarget(self, action: #selector(handleStopTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(startButton)
        buttonStack.addArrangedSubview(stopButton)

        contentStack.addArrangedSubview(previewView)
        contentStack.addArrangedSubview(timerLabel)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    @objc private func handleStartTapped() {
        guard state == .idle else { return }
        guard NetworkMonitor.shared.isConnected else {
            statusMessage = "Offline. Connect to the internet to start a practice session."
            state = .error
            return
        }
        guard let userId = appState.userId else {
            statusMessage = "Enter your user ID to begin practicing."
            state = .error
            return
        }

        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.state = .preparing
                self.statusMessage = "Preparing session…"
            }
            do {
                try await self.recordManager.start(on: self.previewView)
                try await ElevenLabsService.shared.startSession(agentID: Constants.agentID, userId: userId)
                await MainActor.run {
                    self.recordingStartDate = Date()
                    self.startTimer()
                    self.state = .recording
                    self.statusMessage = "Recording…"
                }
            } catch {
                await ElevenLabsService.shared.stopSession()
                await MainActor.run {
                    self.stopTimer()
                    self.state = .error
                    self.statusMessage = error.displayMessage
                }
            }
        }
    }

    @objc private func handleStopTapped() {
        guard state == .recording else { return }
        guard let userId = appState.userId else {
            statusMessage = "User ID missing. Restart the session after entering it."
            state = .error
            return
        }

        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.state = .uploading
                self.statusMessage = "Uploading session…"
            }
            do {
                let (fileURL, duration) = try await self.recordManager.stop()
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
                await MainActor.run {
                    self.stopTimer()
                    self.state = .error
                    self.statusMessage = error.displayMessage
                }
            }
        }
    }

    private func updateUIForState() {
        switch state {
        case .idle:
            startButton.isHidden = false
            startButton.isEnabled = true
            stopButton.isHidden = true
            stopButton.isEnabled = false
        case .preparing:
            startButton.isHidden = false
            startButton.isEnabled = false
            stopButton.isHidden = true
            stopButton.isEnabled = false
        case .recording:
            startButton.isHidden = true
            stopButton.isHidden = false
            stopButton.isEnabled = true
        case .uploading:
            startButton.isHidden = true
            stopButton.isHidden = true
        case .error:
            startButton.isHidden = false
            startButton.isEnabled = true
            stopButton.isHidden = true
            stopButton.isEnabled = false
        }
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
    }

    private func cancelOngoingSession() {
        sessionTask?.cancel()
        sessionTask = nil
        if state == .recording {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.recordManager.stop()
                await ElevenLabsService.shared.stopSession()
            }
        }
        stopTimer()
        statusMessage = "Session cancelled."
        state = .idle
    }
}
