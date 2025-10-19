import UIKit

final class HomeViewController: UIViewController {
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 24
    }

    private let appState = AppState.shared
    private var fetchTask: Task<Void, Never>?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerLabel = UILabel()
    private let practiceButton = UIButton(type: .system)
    private let offlineBanner = UILabel()
    private let previewsContainer = UIStackView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = .systemBackground
        configureLayout()
        configureObservers()
        refreshPreviews()
        updateStatusMessage()
        updateLoadingIndicator()
        updateOfflineBanner()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadConversationsIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        fetchTask?.cancel()
    }

    @objc private func handleConversationsChanged() {
        refreshPreviews()
        updateStatusMessage()
    }

    @objc private func handleFetchingChanged() {
        updateLoadingIndicator()
    }

    @objc private func handleErrorChanged() {
        updateStatusMessage()
    }

    @objc private func handleNetworkStatusChanged() {
        updateOfflineBanner()
        if NetworkMonitor.shared.isConnected {
            loadConversationsIfNeeded(force: appState.latestConversations.isEmpty)
        }
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = Constants.verticalSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        headerLabel.text = "Sales Intelligence"
        headerLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .label

        practiceButton.setTitle("Start Practice", for: .normal)
        practiceButton.setTitleColor(.white, for: .normal)
        practiceButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        practiceButton.backgroundColor = .systemBlue
        practiceButton.layer.cornerRadius = 12
        practiceButton.layer.masksToBounds = true
        practiceButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        practiceButton.addTarget(self, action: #selector(handlePracticeTapped), for: .touchUpInside)

        offlineBanner.backgroundColor = .systemOrange
        offlineBanner.textColor = .white
        offlineBanner.font = UIFont.preferredFont(forTextStyle: .subheadline)
        offlineBanner.textAlignment = .center
        offlineBanner.layer.cornerRadius = 10
        offlineBanner.layer.masksToBounds = true
        offlineBanner.numberOfLines = 0
        offlineBanner.text = "Offline. Showing cached sessions."

        let headerStack = UIStackView(arrangedSubviews: [headerLabel, practiceButton])
        headerStack.axis = .vertical
        headerStack.spacing = 16

        let recentHeader = UILabel()
        recentHeader.text = "Recent Sessions"
        recentHeader.font = UIFont.preferredFont(forTextStyle: .headline)
        recentHeader.textColor = .secondaryLabel

        previewsContainer.axis = .vertical
        previewsContainer.spacing = 12

        statusLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .systemRed
        statusLabel.numberOfLines = 0

        activityIndicator.hidesWhenStopped = true

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(offlineBanner)
        contentStack.addArrangedSubview(recentHeader)
        contentStack.addArrangedSubview(previewsContainer)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Constants.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Constants.horizontalPadding),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Constants.verticalSpacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Constants.verticalSpacing),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Constants.horizontalPadding * 2)
        ])
    }

    private func configureObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleConversationsChanged),
                                               name: AppState.NotificationName.conversationsDidChange,
                                               object: appState)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleFetchingChanged),
                                               name: AppState.NotificationName.fetchingStateDidChange,
                                               object: appState)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleErrorChanged),
                                               name: AppState.NotificationName.errorDidChange,
                                               object: appState)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleNetworkStatusChanged),
                                               name: NetworkMonitor.NotificationName.statusDidChange,
                                               object: nil)
    }

    @objc private func handlePracticeTapped() {
        tabBarController?.selectedIndex = 1
    }

    private func refreshPreviews() {
        previewsContainer.arrangedSubviews.forEach { subview in
            previewsContainer.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let previews = Array(appState.latestConversations.prefix(3))
        if previews.isEmpty {
            let placeholder = makePlaceholderView(text: "No sessions yet. Start a practice to see insights here.")
            previewsContainer.addArrangedSubview(placeholder)
            return
        }

        previews.forEach { preview in
            let button = makePreviewButton(for: preview)
            previewsContainer.addArrangedSubview(button)
        }
    }

    private func updateStatusMessage() {
        if let message = appState.errorMessage, !message.isEmpty {
            statusLabel.text = message
            statusLabel.isHidden = false
            return
        }
        statusLabel.text = nil
        statusLabel.isHidden = true
    }

    private func updateLoadingIndicator() {
        if appState.isFetching {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func updateOfflineBanner() {
        let isOffline = !NetworkMonitor.shared.isConnected
        offlineBanner.isHidden = !isOffline
    }

    func loadConversationsIfNeeded(force: Bool = false) {
        guard NetworkMonitor.shared.isConnected else {
            updateOfflineBanner()
            return
        }

        let needsFetch: Bool
        if force {
            needsFetch = true
        } else if let lastFetch = appState.lastFetchedAt {
            needsFetch = Date().timeIntervalSince(lastFetch) > 60
        } else {
            needsFetch = true
        }

        guard needsFetch, !appState.isFetching else { return }

        appState.isFetching = true
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let previews = try await NetworkClient.shared.fetchConversations(userId: self.appState.userId)
                await MainActor.run {
                    self.appState.updateConversations(previews)
                    self.appState.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.appState.errorMessage = error.displayMessage
                }
            }
            await MainActor.run {
                self.appState.isFetching = false
            }
        }
    }

    private func makePlaceholderView(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12

        let label = UILabel()
        label.text = text
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])

        return container
    }

    private func makePreviewButton(for preview: ConversationPreview) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.numberOfLines = 0

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let summaryText = preview.data
        let attributedTitle = NSMutableAttributedString(string: "Session \(preview.id)\n", attributes: titleAttributes)
        attributedTitle.append(NSAttributedString(string: summaryText, attributes: subtitleAttributes))
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.accessibilityIdentifier = preview.id
        button.addTarget(self, action: #selector(handlePreviewTap(_:)), for: .touchUpInside)
        return button
    }

    @objc private func handlePreviewTap(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let preview = appState.latestConversations.first(where: { $0.id == id }) else {
            return
        }
        showDetail(for: preview)
    }

    private func showDetail(for preview: ConversationPreview) {
        let controller = SessionDetailViewController(sessionId: preview.id)
        navigationController?.pushViewController(controller, animated: true)
    }

    // No date formatter needed with simplified preview payload.
}
