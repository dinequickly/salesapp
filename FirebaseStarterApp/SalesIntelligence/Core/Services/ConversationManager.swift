import Combine
import ElevenLabs

@MainActor
final class ConversationManager: ObservableObject {
    enum AuthMode {
        case publicAgent(agentId: String)
        case conversationTokenProvider(() async throws -> String)
    }

    @Published private(set) var state: ConversationState = .idle
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isMuted: Bool = true
    @Published private(set) var metadata: ConversationMetadataEvent?

    var hasActiveConversation: Bool {
        state.isActive
    }

    private var conversation: Conversation?
    private var conversationCancellables: Set<AnyCancellable> = []

    func startConversation(authMode: AuthMode, config: ConversationConfig = .init()) async throws {
        tearDownConversation()
        messages = []
        isMuted = true
        metadata = nil

        let activeConversation: Conversation
        switch authMode {
        case let .publicAgent(agentId):
            activeConversation = try await ElevenLabs.startConversation(agentId: agentId, config: config)
        case let .conversationTokenProvider(provider):
            activeConversation = try await ElevenLabs.startConversation(tokenProvider: provider, config: config)
        }

        bind(to: activeConversation)
        conversation = activeConversation
    }

    func sendMessage(_ text: String) async throws {
        guard let conversation else { throw ConversationError.notConnected }
        try await conversation.sendMessage(text)
    }

    func toggleMute() async throws {
        guard let conversation else { throw ConversationError.notConnected }
        try await conversation.toggleMute()
    }

    func setMuted(_ muted: Bool) async throws {
        guard let conversation else { throw ConversationError.notConnected }
        try await conversation.setMuted(muted)
    }

    func endConversation() async {
        guard let conversation else { return }
        await conversation.endConversation()
        tearDownConversation()
    }

    func reset() {
        tearDownConversation()
        state = .idle
        messages = []
        isMuted = true
        metadata = nil
    }

    private func bind(to conversation: Conversation) {
        conversationCancellables.removeAll()

        conversation.$state
            .sink { [weak self] state in
                print("Connection state: \(state)")
                self?.state = state
            }
            .store(in: &conversationCancellables)

        conversation.$messages
            .sink { [weak self] messages in
                for message in messages {
                    print("\(message.role): \(message.content)")
                }
                self?.messages = messages
            }
            .store(in: &conversationCancellables)

        conversation.$isMuted
            .sink { [weak self] isMuted in
                self?.isMuted = isMuted
            }
            .store(in: &conversationCancellables)

        conversation.$conversationMetadata
            .sink { [weak self] metadata in
                self?.metadata = metadata
            }
            .store(in: &conversationCancellables)
    }

    private func tearDownConversation() {
        conversationCancellables.removeAll()
        conversation = nil
    }
}
