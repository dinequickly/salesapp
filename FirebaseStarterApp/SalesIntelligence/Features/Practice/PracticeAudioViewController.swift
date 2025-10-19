import Combine
import ElevenLabs
import UIKit

final class PracticeAudioViewController: UIViewController {
    private let conversationManager = ConversationManager()
    private var managerCancellables: Set<AnyCancellable> = []

    private var startTask: Task<Void, Never>?
    private var muteTask: Task<Void, Never>?
    private var endTask: Task<Void, Never>?

    private var currentState: ConversationState = .idle

    private var statusMessage: String = "Idle" {
        didSet { statusLabel.text = statusMessage }
    }

    private let contentStack = UIStackView()
    private let statusLabel = UILabel()
    private let controlsStack = UIStackView()
    private let startButton = UIButton(type: .system)
    private let muteButton = UIButton(type: .system)
    private let endButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Audio"
        view.backgroundColor = .systemBackground

        configureLayout()
        bindConversationManager()
        updateUI(for: .idle)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            Task { [weak self] in
                guard let self else { return }
                await self.conversationManager.endConversation()
                self.conversationManager.reset()
            }
        }
    }

    deinit {
        startTask?.cancel()
        muteTask?.cancel()
        endTask?.cancel()
    }

    // MARK: - Setup

    private func configureLayout() {
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        statusLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = statusMessage

        activityIndicator.hidesWhenStopped = true

        controlsStack.axis = .horizontal
        controlsStack.spacing = 12

        configure(startButton,
                  title: "Start Conversation",
                  backgroundColor: .systemGreen,
                  action: #selector(handleStartTapped))
        configure(muteButton,
                  title: "Mute",
                  backgroundColor: .systemOrange,
                  action: #selector(handleMuteTapped))
        configure(endButton,
                  title: "End Conversation",
                  backgroundColor: .systemRed,
                  action: #selector(handleEndTapped))

        controlsStack.addArrangedSubview(startButton)
        controlsStack.addArrangedSubview(muteButton)
        controlsStack.addArrangedSubview(endButton)

        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(activityIndicator)
        contentStack.addArrangedSubview(controlsStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        startButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        muteButton.heightAnchor.constraint(equalTo: startButton.heightAnchor).isActive = true
        endButton.heightAnchor.constraint(equalTo: startButton.heightAnchor).isActive = true
    }

    private func configure(_ button: UIButton, title: String, backgroundColor: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - Binding

    private func bindConversationManager() {
        conversationManager.$state
            .sink { [weak self] newState in
                self?.updateUI(for: newState)
            }
            .store(in: &managerCancellables)

        conversationManager.$isMuted
            .sink { [weak self] isMuted in
                self?.updateMuteButtonTitle(isMuted: isMuted)
            }
            .store(in: &managerCancellables)
    }

    // MARK: - Actions

    @objc private func handleStartTapped() {
        guard startTask == nil else { return }
        startTask = Task { [weak self] in
            guard let self else { return }
            defer { startTask = nil }
            do {
                let config = conversationConfig()
                try await conversationManager.startConversation(authMode: currentAuthMode(), config: config)
            } catch {
                await MainActor.run {
                    self.statusMessage = error.localizedDescription
                    self.updateUI(for: .error(.connectionFailed(error.localizedDescription)))
                }
            }
        }
    }

    @objc private func handleMuteTapped() {
        guard muteTask == nil else { return }
        muteTask = Task { [weak self] in
            guard let self else { return }
            defer { muteTask = nil }
            do {
                try await conversationManager.toggleMute()
            } catch {
                await MainActor.run {
                    self.statusMessage = error.localizedDescription
                    self.updateUI(for: .error(.microphoneToggleFailed(error.localizedDescription)))
                }
            }
        }
    }

    @objc private func handleEndTapped() {
        guard endTask == nil else { return }
        endTask = Task { [weak self] in
            guard let self else { return }
            defer { endTask = nil }
            await conversationManager.endConversation()
        }
    }

    // MARK: - Helpers

    private func currentAuthMode() -> ConversationManager.AuthMode {
        if Constants.ElevenLabs.useConversationToken {
            return .conversationTokenProvider {
                try await Constants.ElevenLabs.fetchConversationToken()
            }
        } else {
            return .publicAgent(agentId: Constants.ElevenLabs.agentID)
        }
    }

    private func conversationConfig() -> ConversationConfig {
        var config = ConversationConfig()
        config.userId = AppState.shared.userId
        if Constants.ElevenLabs.textOnlyTesting {
            config.conversationOverrides = ConversationOverrides(textOnly: true)
        }
        return config
    }

    private func updateUI(for state: ConversationState) {
        currentState = state
        statusMessage = statusText(for: state)

        switch state {
        case .idle:
            startButton.isEnabled = true
            startButton.setTitle("Start Conversation", for: .normal)
            muteButton.isEnabled = false
            endButton.isEnabled = false
            activityIndicator.stopAnimating()
        case .connecting:
            startButton.isEnabled = false
            startButton.setTitle("Connecting…", for: .normal)
            muteButton.isEnabled = false
            endButton.isEnabled = true
            activityIndicator.startAnimating()
        case .active:
            startButton.isEnabled = false
            startButton.setTitle("Conversation Active", for: .normal)
            muteButton.isEnabled = true
            endButton.isEnabled = true
            activityIndicator.stopAnimating()
        case let .ended(reason):
            startButton.isEnabled = true
            startButton.setTitle("Restart Conversation", for: .normal)
            muteButton.isEnabled = false
            endButton.isEnabled = false
            activityIndicator.stopAnimating()
            statusMessage = "Conversation ended: \(endReasonDescription(reason))"
        case let .error(error):
            startButton.isEnabled = true
            startButton.setTitle("Retry Conversation", for: .normal)
            muteButton.isEnabled = false
            endButton.isEnabled = false
            activityIndicator.stopAnimating()
            statusMessage = error.localizedDescription
        }

        updateMuteButtonTitle(isMuted: conversationManager.isMuted)
    }

    private func updateMuteButtonTitle(isMuted: Bool) {
        muteButton.setTitle(isMuted ? "Unmute" : "Mute", for: .normal)
        muteButton.alpha = (currentState.isActive ? 1.0 : 0.5)
    }

    private func statusText(for state: ConversationState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .connecting:
            return "Connecting to agent…"
        case let .active(info):
            return "Live with agent \(info.agentId)"
        case let .ended(reason):
            return "Conversation ended: \(endReasonDescription(reason))"
        case let .error(error):
            return error.localizedDescription
        }
    }

    private func endReasonDescription(_ reason: EndReason) -> String {
        switch reason {
        case .userEnded:
            return "Ended by user."
        case .agentNotConnected:
            return "Agent unavailable."
        case .remoteDisconnected:
            return "Disconnected remotely."
        }
    }
}
