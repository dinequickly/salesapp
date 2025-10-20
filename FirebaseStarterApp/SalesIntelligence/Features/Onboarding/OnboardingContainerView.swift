import SwiftUI
import ElevenLabs

struct OnboardingContainerView: View {
    @ObservedObject private var supabase = SupabaseService.shared
    @StateObject private var viewModel = OnboardingViewModel()
    var onCompletion: () -> Void

    var body: some View {
        content
            .animation(.easeInOut, value: supabase.step)
            .onAppear { handleStepChange(supabase.step) }
            .onChange(of: supabase.step) { newValue in
                if newValue == .completed {
                    onCompletion()
                } else {
                    handleStepChange(newValue)
                }
            }
            .onChange(of: supabase.profile?.id) { _ in
                handleStepChange(supabase.step)
            }
    }

    @ViewBuilder
    private var content: some View {
        if supabase.isInitializing {
            VStack {
                Spacer()
                ProgressView("Loading…")
                    .progressViewStyle(.circular)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    stepView
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Onboarding")
                .font(.largeTitle).bold()
            Text(supabase.step.title)
                .font(.title2)
                .foregroundColor(.secondary)
            ProgressView(value: progressValue, total: Double(OnboardingStep.allCases.count))
                .progressViewStyle(.linear)
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch supabase.step {
        case .account:
            accountStep
        case .jobRole:
            jobRoleStep
        case .linkedin:
            linkedinStep
        case .voice:
            VoiceOnboardingView(supabase: supabase)
        case .completed:
            completionStep
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose to create a new account or sign in to continue your onboarding progress.")
                .font(.body)
                .foregroundColor(.secondary)

            Picker("Account Action", selection: $viewModel.authMode) {
                Text("Create Account").tag(OnboardingViewModel.AuthMode.signUp)
                Text("Sign In").tag(OnboardingViewModel.AuthMode.signIn)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.authMode) { mode in
                viewModel.handleModeChange(mode)
            }

            VStack(spacing: 14) {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)

                if viewModel.authMode == .signUp {
                    TextField("Full name", text: $viewModel.fullName)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                }

                SecureField(viewModel.authMode == .signUp ? "Password (min 8 characters)" : "Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            PrimaryButton(title: viewModel.isLoading ? "Please wait…" : viewModel.authMode.buttonTitle,
                          isLoading: viewModel.isLoading,
                          enabled: viewModel.canSubmitAccount && !viewModel.isLoading) {
                Task { await viewModel.submitAccount() }
            }
        }
    }

    private var jobRoleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tell the agent about your role to personalise the onboarding experience.")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Job description")
                    .font(.headline)

                TextEditor(text: $viewModel.jobDescription)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            PrimaryButton(title: viewModel.isLoading ? "Saving…" : "Continue",
                          isLoading: viewModel.isLoading,
                          enabled: viewModel.canSaveJobDescription && !viewModel.isLoading) {
                Task { await viewModel.saveJobDescription() }
            }
        }
    }

    private var linkedinStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add your LinkedIn profile so the team can learn more about you. This step is optional." )
                .font(.body)
                .foregroundColor(.secondary)

            TextField("LinkedIn URL", text: $viewModel.linkedinURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            PrimaryButton(title: viewModel.isLoading ? "Saving…" : "Continue",
                          isLoading: viewModel.isLoading,
                          enabled: viewModel.canSaveLinkedIn && !viewModel.isLoading) {
                Task { await viewModel.saveLinkedIn() }
            }

            Button(action: { Task { await viewModel.skipLinkedIn() } }) {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var completionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.title)
                .bold()

            Text("Your onboarding is complete. Jump into the app to start practicing with the coaching agent.")
                .font(.body)
                .foregroundColor(.secondary)

            PrimaryButton(title: "Enter App", isLoading: false, enabled: true) {
                onCompletion()
            }
        }
    }

    private var progressValue: Double {
        Double(supabase.step.rawValue + 1)
    }

    private func handleStepChange(_ step: OnboardingStep) {
        viewModel.prepareFor(step: step, profile: supabase.profile)
    }
}

private struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 12).fill(enabled ? Color.accentColor : Color.gray.opacity(0.4)))
        }
        .disabled(!enabled)
    }
}

private struct VoiceOnboardingView: View {
    @ObservedObject var supabase: SupabaseService
    @ObservedObject private var conversationManager = ElevenLabsService.shared.conversationManager
    @State private var isWorking = false
    @State private var isCompleting = false
    @State private var errorMessage: String?

    private var hasActiveConversation: Bool {
        conversationManager.hasActiveConversation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speak with the ElevenLabs voice agent to finish onboarding. Once you're done, mark the session complete.")
                .font(.body)
                .foregroundColor(.secondary)

            statusCard

            messagesList

            if let message = errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            buttonStack
        }
        .onAppear {
            Task { await ensureSession() }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            Text(statusDescription(for: conversationManager.state))
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let conversationId = conversationManager.metadata?.conversationId ?? supabase.voiceConversationId {
                Text("Conversation ID: \(conversationId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private var messagesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)

            let liveMessages = conversationManager.messages
            let recordedMessages = supabase.voiceTranscript

            if liveMessages.isEmpty && recordedMessages.isEmpty {
                Text("No messages yet. Start the session to speak with the agent.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(liveMessages, id: \.id) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(roleLabel(for: message.role))
                                    .font(.caption)
                                    .foregroundColor(message.role == .user ? .accentColor : .secondary)
                                Text(message.content)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill)))
                        }

                        if liveMessages.isEmpty {
                            ForEach(recordedMessages) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.role == "user" ? "You" : "Agent")
                                        .font(.caption)
                                        .foregroundColor(message.role == "user" ? .accentColor : .secondary)
                                    Text(message.content)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill)))
                            }
                        }
                    }
                }
                .frame(minHeight: 140, maxHeight: 220)
            }
        }
    }

    private var buttonStack: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: hasActiveConversation ? "End Session" : (isWorking ? "Starting…" : "Start Voice Session"),
                          isLoading: isWorking,
                          enabled: !isWorking) {
                Task {
                    if hasActiveConversation {
                        await stopConversation()
                    } else {
                        await startConversation()
                    }
                }
            }

            PrimaryButton(title: isCompleting ? "Finishing…" : "Mark Onboarding Complete",
                          isLoading: isCompleting,
                          enabled: !isCompleting) {
                Task { await completeOnboarding() }
            }
        }
    }

    private func ensureSession() async {
        do {
            _ = try await supabase.ensureVoiceSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startConversation() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await supabase.ensureVoiceSession()
            guard let userId = supabase.profile?.id else {
                throw SupabaseService.ServiceError.missingProfile
            }
            try await ElevenLabsService.shared.startSession(agentID: Constants.ElevenLabs.agentID,
                                                            userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopConversation() async {
        await ElevenLabsService.shared.stopSession()
    }

    private func completeOnboarding() async {
        guard !isCompleting else { return }
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }

        do {
            if hasActiveConversation {
                await ElevenLabsService.shared.stopSession()
            }

            let transcript = conversationManager.messages.map { message in
                VoiceTranscriptMessage(
                    id: message.id,
                    role: transcriptRole(for: message.role),
                    content: message.content,
                    timestamp: message.timestamp
                )
            }

            let finalTranscript = transcript.isEmpty ? supabase.voiceTranscript : transcript
            let conversationId = conversationManager.metadata?.conversationId
            try await supabase.completeVoiceOnboarding(conversationId: conversationId,
                                                       transcript: finalTranscript)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statusDescription(for state: ConversationState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .connecting:
            return "Connecting to agent…"
        case .active:
            return "Live conversation"
        case let .ended(reason):
            return "Ended (\(reasonLabel(for: reason)))"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    private func reasonLabel(for reason: EndReason) -> String {
        switch reason {
        case .userEnded:
            return "You ended the call"
        case .agentNotConnected:
            return "Agent unavailable"
        case .remoteDisconnected:
            return "Disconnected"
        }
    }

    private func roleLabel(for role: Message.Role) -> String {
        switch role {
        case .user:
            return "You"
        case .agent:
            return "Agent"
        }
    }

    private func transcriptRole(for role: Message.Role) -> String {
        switch role {
        case .user:
            return "user"
        case .agent:
            return "agent"
        }
    }
}
