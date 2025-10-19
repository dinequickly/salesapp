import Foundation

struct ConversationAnalysis: Codable, Equatable {
    let sessionId: String
    let title: String
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case summary
        case strengths
        case improvements
        case createdAt = "created_at"
    }

    init(sessionId: String,
         title: String,
         summary: String,
         strengths: [String],
         improvements: [String],
         createdAt: Date? = nil) {
        self.sessionId = sessionId
        self.title = title
        self.summary = summary
        self.strengths = strengths
        self.improvements = improvements
        self.createdAt = createdAt
    }
}
