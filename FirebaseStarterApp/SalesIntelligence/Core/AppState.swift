import Foundation

final class AppState {
    static let shared = AppState()

    enum NotificationName {
        static let conversationsDidChange = Notification.Name("AppState.conversationsDidChange")
        static let fetchingStateDidChange = Notification.Name("AppState.fetchingStateDidChange")
        static let errorDidChange = Notification.Name("AppState.errorDidChange")
    }

    private let defaults: UserDefaults
    private let userIdKey = "user_id"
    private let conversationCacheKey = "latest_conversations"

    private(set) var userId: String {
        didSet {
            defaults.set(userId, forKey: userIdKey)
        }
    }

    var latestConversations: [ConversationPreview] = [] {
        didSet {
            persistLatestConversations()
            NotificationCenter.default.post(name: NotificationName.conversationsDidChange, object: self)
        }
    }

    var lastFetchedAt: Date?

    var isFetching: Bool = false {
        didSet {
            guard oldValue != isFetching else { return }
            NotificationCenter.default.post(name: NotificationName.fetchingStateDidChange, object: self)
        }
    }

    var errorMessage: String? {
        didSet {
            NotificationCenter.default.post(name: NotificationName.errorDidChange, object: self)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedId = defaults.string(forKey: userIdKey) {
            userId = storedId
        } else {
            let newId = UUID().uuidString
            userId = newId
            defaults.set(newId, forKey: userIdKey)
        }
        loadCachedConversations()
    }

    func setUserId(_ newUserId: String) {
        userId = newUserId
    }

    func updateConversations(_ conversations: [ConversationPreview], fetchedAt: Date = Date()) {
        lastFetchedAt = fetchedAt
        latestConversations = conversations
    }

    func addConversation(_ conversation: ConversationPreview, fetchedAt: Date = Date()) {
        var updated = latestConversations.filter { $0.id != conversation.id }
        updated.insert(conversation, at: 0)
        updateConversations(updated, fetchedAt: fetchedAt)
    }

    func clearError() {
        errorMessage = nil
    }

    func loadCachedConversations() {
        guard let data = defaults.data(forKey: conversationCacheKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([ConversationPreview].self, from: data)
            lastFetchedAt = Date()
            latestConversations = decoded
        } catch {
            defaults.removeObject(forKey: conversationCacheKey)
        }
    }

    private func persistLatestConversations() {
        do {
            let data = try JSONEncoder().encode(latestConversations)
            defaults.set(data, forKey: conversationCacheKey)
        } catch {
            defaults.removeObject(forKey: conversationCacheKey)
        }
    }
}
