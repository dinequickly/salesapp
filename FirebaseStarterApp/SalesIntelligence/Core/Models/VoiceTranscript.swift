import Foundation
import Supabase

struct VoiceTranscriptMessage: Codable, Equatable, Identifiable {
    let id: String
    let role: String
    let content: String
    let timestamp: Date

    init(id: String = UUID().uuidString,
         role: String,
         content: String,
         timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    init?(json: AnyJSON) {
        guard case let .object(dictionary) = json else { return nil }
        guard
            let id = dictionary["id"]?.stringValue,
            let role = dictionary["role"]?.stringValue,
            let content = dictionary["content"]?.stringValue,
            let timestampString = dictionary["timestamp"]?.stringValue,
            let timestamp = ISO8601DateFormatter().date(from: timestampString)
        else {
            return nil
        }
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    func toJSON() -> AnyJSON {
        let formatter = ISO8601DateFormatter()
        return .object([
            "id": .string(id),
            "role": .string(role),
            "content": .string(content),
            "timestamp": .string(formatter.string(from: timestamp))
        ])
    }
}

struct ProfileMetadata {
    var fullName: String?
    var jobDescription: String?
    var linkedinURL: String?
    var linkedinCompleted: Bool
    var onboardingCompleted: Bool
    var voiceOnboardingCompleted: Bool
    var voiceSessionId: String?
    var voiceConversationId: String?
    var voiceTranscript: [VoiceTranscriptMessage]

    init(fullName: String? = nil,
         jobDescription: String? = nil,
         linkedinURL: String? = nil,
         linkedinCompleted: Bool = false,
         onboardingCompleted: Bool = false,
         voiceOnboardingCompleted: Bool = false,
         voiceSessionId: String? = nil,
         voiceConversationId: String? = nil,
         voiceTranscript: [VoiceTranscriptMessage] = []) {
        self.fullName = fullName
        self.jobDescription = jobDescription
        self.linkedinURL = linkedinURL
        self.linkedinCompleted = linkedinCompleted
        self.onboardingCompleted = onboardingCompleted
        self.voiceOnboardingCompleted = voiceOnboardingCompleted
        self.voiceSessionId = voiceSessionId
        self.voiceConversationId = voiceConversationId
        self.voiceTranscript = voiceTranscript
    }

    init(json: [String: AnyJSON]) {
        fullName = json["full_name"]?.stringValue
        jobDescription = json["job_description"]?.stringValue
        linkedinURL = json["linkedin_url"]?.stringValue
        linkedinCompleted = json["linkedin_completed"]?.boolValue ?? false
        onboardingCompleted = json["onboarding_completed"]?.boolValue ?? false
        voiceOnboardingCompleted = json["voice_onboarding_completed"]?.boolValue ?? false
        voiceSessionId = json["voice_session_id"]?.stringValue
        voiceConversationId = json["voice_conversation_id"]?.stringValue

        if case let .array(transcriptArray)? = json["voice_transcript"] {
            voiceTranscript = transcriptArray.compactMap { VoiceTranscriptMessage(json: $0) }
        } else {
            voiceTranscript = []
        }
    }

    func dictionary() -> [String: AnyJSON] {
        var result: [String: AnyJSON] = [
            "onboarding_completed": .bool(onboardingCompleted),
            "voice_onboarding_completed": .bool(voiceOnboardingCompleted),
            "linkedin_completed": .bool(linkedinCompleted)
        ]

        result["full_name"] = fullName.map { .string($0) } ?? .null
        result["job_description"] = jobDescription.map { .string($0) } ?? .null
        result["linkedin_url"] = linkedinURL.map { .string($0) } ?? .null
        result["voice_session_id"] = voiceSessionId.map { .string($0) } ?? .null
        result["voice_conversation_id"] = voiceConversationId.map { .string($0) } ?? .null
        result["voice_transcript"] = .array(voiceTranscript.map { $0.toJSON() })

        return result
    }
}

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case let .string(value): return value
        case let .number(value): return String(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case let .bool(value): return value
        case let .number(value): return value != 0
        case let .string(value): return (value as NSString).boolValue
        default: return nil
        }
    }
}
