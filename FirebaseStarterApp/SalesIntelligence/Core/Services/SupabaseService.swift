import Combine
import Foundation
import Supabase

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    enum ServiceError: LocalizedError {
        case configurationMissing
        case notAuthenticated
        case missingProfile

        var errorDescription: String? {
            switch self {
            case .configurationMissing:
                return "Supabase credentials are not configured."
            case .notAuthenticated:
                return "You must be signed in to complete this action."
            case .missingProfile:
                return "Profile data missing. Complete account setup first."
            }
        }
    }

    @Published private(set) var session: Session?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var step: OnboardingStep = .account
    @Published private(set) var isInitializing = true
    @Published private(set) var voiceSessionId: String?
    @Published private(set) var voiceTranscript: [VoiceTranscriptMessage] = []
    @Published private(set) var voiceConversationId: String?

    private let client: SupabaseClient
    private var authTask: Task<Void, Never>?

    private init() {
        guard
            let url = URL(string: Constants.Supabase.urlString),
            !Constants.Supabase.anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Configure Supabase credentials in Constants.Supabase before running the app.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Constants.Supabase.anonKey,
            options: SupabaseClientOptions()
        )

        authTask = Task { [weak self] in
            guard let self else { return }
            for await change in await client.auth.authStateChanges {
                await self.handleAuthEvent(change.event, session: change.session)
            }
        }
    }

    deinit {
        authTask?.cancel()
    }

    // MARK: - Auth Lifecycle

    private func handleAuthEvent(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedOut:
            self.session = nil
            profile = nil
            voiceSessionId = nil
            voiceTranscript = []
            voiceConversationId = nil
            step = .account
            AppState.shared.setUserId("")
        case .signedIn, .tokenRefreshed, .initialSession:
            guard let session else { break }
            self.session = session
            await loadProfile(for: session)
        default:
            break
        }

        if isInitializing {
            isInitializing = false
        }
    }

    private func loadProfile(for session: Session) async {
        let metadata = ProfileMetadata(json: session.user.userMetadata)

        let profile = UserProfile(
            id: session.user.id.uuidString,
            email: session.user.email,
            fullName: metadata.fullName,
            linkedinURL: metadata.linkedinURL,
            linkedinCompleted: metadata.linkedinCompleted,
            jobDescription: metadata.jobDescription,
            onboardingCompleted: metadata.onboardingCompleted,
            voiceOnboardingCompleted: metadata.voiceOnboardingCompleted,
            voiceSessionId: metadata.voiceSessionId,
            voiceConversationId: metadata.voiceConversationId,
            voiceTranscript: metadata.voiceTranscript
        )

        self.profile = profile
        voiceSessionId = metadata.voiceSessionId
        voiceConversationId = metadata.voiceConversationId
        voiceTranscript = metadata.voiceTranscript
        AppState.shared.setUserId(profile.id)
        setStep(for: profile)
    }

    private func setStep(for profile: UserProfile?) {
        guard let profile else {
            step = .account
            return
        }

        if profile.onboardingCompleted {
            step = .completed
            return
        }

        if profile.requiresJobDescription {
            step = .jobRole
            return
        }

        if profile.requiresLinkedIn {
            step = .linkedin
            return
        }

        if profile.requiresVoiceOnboarding {
            step = .voice
            return
        }

        step = .completed
    }

    private func currentMetadata() throws -> ProfileMetadata {
        guard let session else { throw ServiceError.notAuthenticated }
        if let profile {
            return ProfileMetadata(
                fullName: profile.fullName,
                jobDescription: profile.jobDescription,
                linkedinURL: profile.linkedinURL,
                linkedinCompleted: profile.linkedinCompleted,
                onboardingCompleted: profile.onboardingCompleted,
                voiceOnboardingCompleted: profile.voiceOnboardingCompleted,
                voiceSessionId: profile.voiceSessionId,
                voiceConversationId: profile.voiceConversationId,
                voiceTranscript: profile.voiceTranscript
            )
        }
        return ProfileMetadata(json: session.user.userMetadata)
    }

    private func save(_ metadata: ProfileMetadata) async throws {
        guard var currentSession = session else { throw ServiceError.notAuthenticated }
        let updatedUser = try await client.auth.update(user: UserAttributes(data: metadata.dictionary()))
        currentSession.user = updatedUser
        self.session = currentSession
        await loadProfile(for: currentSession)
    }

    // MARK: - Public API

    func signUp(email: String, password: String, fullName: String) async throws {
        let metadata = ProfileMetadata(fullName: fullName)
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: metadata.dictionary()
        )

        guard let session = response.session else {
            throw ServiceError.notAuthenticated
        }

        self.session = session
        await loadProfile(for: session)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        self.session = session
        await loadProfile(for: session)
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Ignore sign-out errors and reset local state
            self.session = nil
            profile = nil
            voiceSessionId = nil
            voiceConversationId = nil
            voiceTranscript = []
            step = .account
        }
    }

    func updateJobDescription(_ description: String) async throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.invalidJobDescription
        }

        var metadata = try currentMetadata()
        metadata.jobDescription = trimmed
        try await save(metadata)
    }

    func updateLinkedInURL(_ rawURL: String?) async throws {
        let value = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata = try currentMetadata()
        metadata.linkedinCompleted = true
        if let value, !value.isEmpty {
            metadata.linkedinURL = value
        } else {
            metadata.linkedinURL = nil
        }
        try await save(metadata)
    }

    @discardableResult
    func ensureVoiceSession() async throws -> String {
        var metadata = try currentMetadata()
        if let id = metadata.voiceSessionId {
            voiceSessionId = id
            return id
        }

        let newId = UUID().uuidString
        metadata.voiceSessionId = newId
        metadata.voiceOnboardingCompleted = false
        metadata.onboardingCompleted = false
        metadata.voiceTranscript = []
        metadata.voiceConversationId = nil
        try await save(metadata)
        voiceSessionId = newId
        return newId
    }

    func completeVoiceOnboarding(conversationId: String?, transcript: [VoiceTranscriptMessage]) async throws {
        var metadata = try currentMetadata()
        metadata.voiceConversationId = conversationId
        metadata.voiceTranscript = transcript
        metadata.voiceOnboardingCompleted = true
        metadata.onboardingCompleted = true
        try await save(metadata)
    }

    func refreshProfile() async {
        guard let session else { return }
        await loadProfile(for: session)
    }

    // MARK: - Validation

    enum ValidationError: LocalizedError {
        case invalidJobDescription
        case invalidLinkedInURL

        var errorDescription: String? {
            switch self {
            case .invalidJobDescription:
                return "Add a few words describing your role."
            case .invalidLinkedInURL:
                return "Provide a valid LinkedIn URL."
            }
        }
    }
}
