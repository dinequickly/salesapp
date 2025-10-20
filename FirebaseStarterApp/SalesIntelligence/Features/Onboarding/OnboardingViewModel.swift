import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum AuthMode: Int, CaseIterable {
        case signUp
        case signIn

        var title: String {
            switch self {
            case .signUp:
                return "Create Account"
            case .signIn:
                return "Sign In"
            }
        }

        var buttonTitle: String {
            switch self {
            case .signUp:
                return "Create Account"
            case .signIn:
                return "Sign In"
            }
        }
    }

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var fullName: String = ""
    @Published var jobDescription: String = ""
    @Published var linkedinURL: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var authMode: AuthMode = .signUp

    private let supabase: SupabaseService

    init(supabase: SupabaseService? = nil) {
        self.supabase = supabase ?? SupabaseService.shared
    }

    func prepareFor(step: OnboardingStep, profile: UserProfile?) {
        errorMessage = nil

        switch step {
        case .account:
            break
        case .jobRole:
            if jobDescription.isEmpty {
                jobDescription = profile?.jobDescription ?? ""
            }
        case .linkedin:
            if linkedinURL.isEmpty {
                linkedinURL = profile?.linkedinURL ?? ""
            }
        case .voice, .completed:
            break
        }
    }

    func handleModeChange(_ mode: AuthMode) {
        errorMessage = nil
        if mode == .signIn {
            fullName = ""
        }
    }

    private var normalizedLinkedInURL: String? {
        let trimmed = linkedinURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty, url.host != nil {
            return trimmed
        }

        let prefixed = "https://" + trimmed
        if let url = URL(string: prefixed), url.host != nil {
            return prefixed
        }

        return nil
    }

    var canSubmitAccount: Bool {
        switch authMode {
        case .signUp:
            return email.isValidEmail
                && password.count >= 8
                && !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .signIn:
            return email.isValidEmail && !password.isEmpty
        }
    }

    var canSaveJobDescription: Bool {
        !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSaveLinkedIn: Bool {
        normalizedLinkedInURL != nil
    }

    func submitAccount() async {
        guard canSubmitAccount else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch authMode {
        case .signUp:
            await perform { [self] in
                try await self.supabase.signUp(
                    email: trimmedEmail,
                    password: self.password,
                    fullName: self.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        case .signIn:
            await perform { [self] in
                try await self.supabase.signIn(
                    email: trimmedEmail,
                    password: self.password
                )
            }
        }
    }

    func saveJobDescription() async {
        guard canSaveJobDescription else { return }
        await perform { [self] in
            try await self.supabase.updateJobDescription(self.jobDescription)
        }
    }

    func saveLinkedIn() async {
        guard canSaveLinkedIn else { return }
        guard let normalized = normalizedLinkedInURL else { return }
        await perform { [self] in
            try await self.supabase.updateLinkedInURL(normalized)
            self.linkedinURL = normalized
        }
    }

    func skipLinkedIn() async {
        await perform { [self] in
            try await self.supabase.updateLinkedInURL(nil)
            self.linkedinURL = ""
        }
    }

    private func perform(operation: @escaping () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
