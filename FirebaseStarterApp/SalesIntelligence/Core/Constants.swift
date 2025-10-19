import Foundation

enum Constants {
    enum ElevenLabs {
        /// Replace with the agent ID created in the ElevenLabs dashboard.
        static let agentID = "agent_1801k4yzmzs1exz9bee2kep0npbq"

        /// Set to `true` when using private agents that require conversation tokens.
        static let useConversationToken = false

        /// Enable to exercise the SDK in text-only mode without audio output.
        static let textOnlyTesting = false

        static func fetchConversationToken() async throws -> String {
            throw AuthError.notConfigured
        }

        enum AuthError: LocalizedError {
            case notConfigured

            var errorDescription: String? {
                "Configure a secure conversation token provider before enabling private agents."
            }
        }
    }

    enum Endpoint {
        static let listConversations = URL(string: "https://maxipad.app.n8n.cloud/webhook/30f7b004-f692-4fd0-9c7b-e188facb723d")!
        static let analysis = URL(string: "https://maxipad.app.n8n.cloud/webhook/d65a27ed-9a6a-4fb8-afd6-3464cefbde61")!
        static let upload = URL(string: "https://maxipad.app.n8n.cloud/webhook/interview-upload")!
    }
}
