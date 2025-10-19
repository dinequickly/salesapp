import Foundation

struct ConversationAnalysis: Codable, Equatable {
    let sessionId: String
    let transcript: String
    let feedback: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcript
        case feedback
    }

    init(sessionId: String,
         transcript: String,
         feedback: String) {
        self.sessionId = sessionId
        self.transcript = transcript
        self.feedback = feedback
    }
}
