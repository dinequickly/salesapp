import Foundation

enum Constants {
    static let agentID = "agent_1801k4yzmzs1exz9bee2kep0npbq"

    enum Endpoint {
        static let listConversations = URL(string: "https://maxipad.app.n8n.cloud/webhook/30f7b004-f692-4fd0-9c7b-e188facb723d")!
        static let analysis = URL(string: "https://maxipad.app.n8n.cloud/webhook/d65a27ed-9a6a-4fb8-afd6-3464cefbde61")!
        static let upload = URL(string: "https://maxipad.app.n8n.cloud/webhook/interview-upload")!
    }
}
