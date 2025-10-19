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
    private let sessionIdLabel = UILabel()
    private let transcriptHeaderLabel = UILabel()
    private let transcriptLabel = UILabel()
    private let feedbackHeaderLabel = UILabel()
    private let feedbackLabel = UILabel()
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

        [sessionIdLabel, transcriptLabel, feedbackLabel].forEach { label in
            label.numberOfLines = 0
            label.textColor = .label
        }

        sessionIdLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        transcriptLabel.font = UIFont.preferredFont(forTextStyle: .body)
        feedbackLabel.font = UIFont.preferredFont(forTextStyle: .body)

        errorLabel.font = UIFont.preferredFont(forTextStyle: .body)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        retryButton.setTitle("Try Again", for: .normal)
        retryButton.addTarget(self, action: #selector(fetchAnalysis), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        configureSectionLabel(transcriptHeaderLabel, text: "Transcript")
        configureSectionLabel(feedbackHeaderLabel, text: "Feedback")

        contentStack.addArrangedSubview(sessionIdLabel)
        contentStack.addArrangedSubview(transcriptHeaderLabel)
        contentStack.addArrangedSubview(transcriptLabel)
        contentStack.addArrangedSubview(feedbackHeaderLabel)
        contentStack.addArrangedSubview(feedbackLabel)
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
            guard let userId = AppState.shared.userId else {
                await MainActor.run {
                    self.state = .failed("Enter your user ID to view session details.")
                }
                return
            }
            do {
                let analysis = try await NetworkClient.shared.fetchAnalysis(userId: userId, sessionId: sessionId)
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
        sessionIdLabel.isHidden = true
        transcriptHeaderLabel.isHidden = true
        transcriptLabel.isHidden = true
        feedbackHeaderLabel.isHidden = true
        feedbackLabel.isHidden = true
    }

    private func showAnalysis(_ analysis: ConversationAnalysis) {
        activityIndicator.stopAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true

        sessionIdLabel.text = "Session ID: \(analysis.sessionId)"

        transcriptLabel.text = analysis.transcript
        feedbackLabel.text = analysis.feedback

        sessionIdLabel.isHidden = false
        transcriptHeaderLabel.isHidden = analysis.transcript.isEmpty
        transcriptLabel.isHidden = analysis.transcript.isEmpty
        feedbackHeaderLabel.isHidden = analysis.feedback.isEmpty
        feedbackLabel.isHidden = analysis.feedback.isEmpty
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
        retryButton.isHidden = false
        sessionIdLabel.isHidden = true
        transcriptHeaderLabel.isHidden = true
        transcriptLabel.isHidden = true
        feedbackHeaderLabel.isHidden = true
        feedbackLabel.isHidden = true
    }

}
