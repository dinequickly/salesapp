import ElevenLabs
import Foundation

@MainActor
final class ElevenLabsService {
    static let shared = ElevenLabsService()

    private let conversationManager = ConversationManager()

    private init() {}

    func startSession(agentID: String, userId: String) async throws {
        var config = ConversationConfig()
        config.userId = userId
        if Constants.ElevenLabs.textOnlyTesting {
            config.conversationOverrides = ConversationOverrides(textOnly: true)
        }

        try await conversationManager.startConversation(authMode: authMode(agentID: agentID), config: config)
    }

    func stopSession() async {
        await conversationManager.endConversation()
        conversationManager.reset()
    }

    private func authMode(agentID: String) -> ConversationManager.AuthMode {
        if Constants.ElevenLabs.useConversationToken {
            return .conversationTokenProvider {
                try await Constants.ElevenLabs.fetchConversationToken()
            }
        } else {
            return .publicAgent(agentId: agentID)
        }
    }
}
