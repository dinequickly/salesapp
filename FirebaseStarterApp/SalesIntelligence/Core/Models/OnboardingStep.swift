import Foundation

enum OnboardingStep: Int, CaseIterable, Codable {
    case account = 0
    case jobRole
    case linkedin
    case voice
    case completed

    var title: String {
        switch self {
        case .account:
            return "Create Account"
        case .jobRole:
            return "Your Role"
        case .linkedin:
            return "LinkedIn"
        case .voice:
            return "Voice Onboarding"
        case .completed:
            return "All Set"
        }
    }

    var progressValue: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }

    var isFinal: Bool {
        self == .completed
    }
}
