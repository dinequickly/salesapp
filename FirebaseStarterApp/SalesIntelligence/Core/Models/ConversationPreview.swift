import Foundation

struct ConversationPreview: Codable, Equatable, Identifiable {
    let id: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case id = "session_id"
        case data
    }

    init(id: String,
         data: String) {
        self.id = id
        self.data = data
    }
}
