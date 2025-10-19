import UIKit

final class SessionDetailViewController: UIViewController {
    private enum State {
        case loading
        case loaded(ConversationAnalysis)
        case failed(String)
    }

    private let sessionId: String
    private var state: State = .loading {
        didSet { updateUI() }
    }
    private var fetchTask: Task<Void, Never>?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let strengthsLabel = UILabel()
    private let improvementsLabel = UILabel()
    private let strengthsHeaderLabel = UILabel()
    private let improvementsHeaderLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    init(sessionId: String) {
        self.sessionId = sessionId
        super.init(nibName: nil, bundle: nil)
        title = "Session"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        fetchAnalysis()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            fetchTask?.cancel()
        }
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        [titleLabel, summaryLabel, strengthsLabel, improvementsLabel].forEach { label in
            label.numberOfLines = 0
            label.textColor = .label
        }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        summaryLabel.font = UIFont.preferredFont(forTextStyle: .body)
        strengthsLabel.font = UIFont.preferredFont(forTextStyle: .body)
        improvementsLabel.font = UIFont.preferredFont(forTextStyle: .body)

        errorLabel.font = UIFont.preferredFont(forTextStyle: .body)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        retryButton.setTitle("Try Again", for: .normal)
        retryButton.addTarget(self, action: #selector(fetchAnalysis), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        configureSectionLabel(strengthsHeaderLabel, text: "Strengths")
        configureSectionLabel(improvementsHeaderLabel, text: "Improvements")

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(summaryLabel)
        contentStack.addArrangedSubview(strengthsHeaderLabel)
        contentStack.addArrangedSubview(strengthsLabel)
        contentStack.addArrangedSubview(improvementsHeaderLabel)
        contentStack.addArrangedSubview(improvementsLabel)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(retryButton)
        contentStack.addArrangedSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        updateUI()
    }

    private func configureSectionLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
    }

    @objc private func fetchAnalysis() {
        state = .loading
        fetchTask?.cancel()
        fetchTask = Task { [sessionId] in
            do {
                let analysis = try await NetworkClient.shared.fetchAnalysis(userId: AppState.shared.userId, sessionId: sessionId)
                await MainActor.run {
                    self.state = .loaded(analysis)
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error.displayMessage)
                }
            }
        }
    }

    private func updateUI() {
        switch state {
        case .loading:
            showLoadingState()
        case .loaded(let analysis):
            showAnalysis(analysis)
        case .failed(let message):
            showError(message)
        }
    }

    private func showLoadingState() {
        activityIndicator.startAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true
        titleLabel.isHidden = true
        summaryLabel.isHidden = true
        strengthsHeaderLabel.isHidden = true
        strengthsLabel.isHidden = true
        improvementsHeaderLabel.isHidden = true
        improvementsLabel.isHidden = true
    }

    private func showAnalysis(_ analysis: ConversationAnalysis) {
        activityIndicator.stopAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true

        titleLabel.text = analysis.title
        summaryLabel.text = analysis.summary
        strengthsLabel.text = analysis.strengths.joined(separator: "\n• ").prependingBullet()
        improvementsLabel.text = analysis.improvements.joined(separator: "\n• ").prependingBullet()

        titleLabel.isHidden = false
        summaryLabel.isHidden = false
        strengthsHeaderLabel.isHidden = analysis.strengths.isEmpty
        strengthsLabel.isHidden = analysis.strengths.isEmpty
        improvementsHeaderLabel.isHidden = analysis.improvements.isEmpty
        improvementsLabel.isHidden = analysis.improvements.isEmpty
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
        retryButton.isHidden = false
        titleLabel.isHidden = true
        summaryLabel.isHidden = true
        strengthsHeaderLabel.isHidden = true
        strengthsLabel.isHidden = true
        improvementsHeaderLabel.isHidden = true
        improvementsLabel.isHidden = true
    }

}

private extension String {
    func prependingBullet() -> String {
        guard !isEmpty else { return "• (none)" }
        if hasPrefix("•") { return self }
        return "• " + self
    }
}
