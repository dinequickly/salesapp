import Foundation

struct UserProfile: Identifiable, Equatable {
    let id: String
    let email: String?
    var fullName: String?
    var linkedinURL: String?
    var linkedinCompleted: Bool
    var jobDescription: String?
    var onboardingCompleted: Bool
    var voiceOnboardingCompleted: Bool
    var voiceSessionId: String?
    var voiceConversationId: String?
    var voiceTranscript: [VoiceTranscriptMessage]

    var displayName: String {
        fullName ?? email ?? "Guest"
    }

    var requiresJobDescription: Bool {
        (jobDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var requiresLinkedIn: Bool {
        !linkedinCompleted && (linkedinURL?.isEmpty ?? true)
    }

    var requiresVoiceOnboarding: Bool {
        !voiceOnboardingCompleted
    }
}
