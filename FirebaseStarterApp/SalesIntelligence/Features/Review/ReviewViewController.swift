import UIKit

final class ReviewViewController: UITableViewController {
    private let appState = AppState.shared
    private var fetchTask: Task<Void, Never>?
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.frame.size.height = 60
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review"
        tableView.tableFooterView = statusLabel
        tableView.backgroundColor = .systemBackground

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        configureObservers()
        tableView.reloadData()
        updateStatusLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadConversationsIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        fetchTask?.cancel()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        appState.latestConversations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        let preview = appState.latestConversations[indexPath.row]
        cell.textLabel?.text = "Session \(preview.id)"
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.detailTextLabel?.text = preview.data
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let preview = appState.latestConversations[indexPath.row]
        let controller = SessionDetailViewController(sessionId: preview.id)
        navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - Private helpers

    private func configureObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleConversationsChanged),
                                               name: AppState.NotificationName.conversationsDidChange,
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

    @objc private func handleConversationsChanged() {
        tableView.reloadData()
        updateStatusLabel()
        refreshControl?.endRefreshing()
    }

    @objc private func handleErrorChanged() {
        updateStatusLabel()
        refreshControl?.endRefreshing()
    }

    @objc private func handleNetworkStatusChanged() {
        updateStatusLabel()
    }

    @objc private func handleRefresh() {
        loadConversationsIfNeeded(force: true)
    }

    private func updateStatusLabel() {
        if !NetworkMonitor.shared.isConnected {
            statusLabel.text = "Offline. Showing cached sessions."
            statusLabel.isHidden = false
        } else if let error = appState.errorMessage, !error.isEmpty {
            statusLabel.text = error
            statusLabel.isHidden = false
        } else if appState.latestConversations.isEmpty {
            statusLabel.text = "No sessions yet. Pull down to refresh."
            statusLabel.isHidden = false
        } else {
            statusLabel.text = nil
            statusLabel.isHidden = true
        }
    }

    private func loadConversationsIfNeeded(force: Bool = false) {
        guard NetworkMonitor.shared.isConnected else {
            refreshControl?.endRefreshing()
            return
        }

        guard let userId = appState.userId else {
            statusLabel.text = "Enter your user ID to load conversations."
            statusLabel.isHidden = false
            refreshControl?.endRefreshing()
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

        guard needsFetch, !appState.isFetching else {
            if appState.isFetching { refreshControl?.beginRefreshing() }
            return
        }

        appState.isFetching = true
        refreshControl?.beginRefreshing()
        fetchTask?.cancel()
        fetchTask = Task {
            do {
                let previews = try await NetworkClient.shared.fetchConversations(userId: userId)
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
                self.refreshControl?.endRefreshing()
            }
        }
    }

}
