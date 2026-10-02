import SwiftUI
import UIKit

// MARK: - Vue principale

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var showingSettings = false
    @State private var showingModels = false
    @State private var showingSidebar = false
    @State private var showingPersona = false
    @State private var isListening = false
    @State private var speaking = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    SidebarView(viewModel: viewModel)
                        .frame(width: 280)
                }

                mainContent
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        Button {
                            showingSidebar.toggle()
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if viewModel.isModelLoaded {
                            Button {
                                _ = viewModel.store.createNewConversation()
                                AppUtils.haptic(.light)
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }

                            Button {
                                showingModels = true
                            } label: {
                                if let info = viewModel.currentModelInfo {
                                    Text(info.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "cpu")
                                }
                            }

                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingModels) {
                ModelListView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPersona) {
                PersonaView(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingSidebar) {
                SidebarView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .alert("Erreur", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.refreshInstalledModels()
            }
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var mainContent: some View {
        if !viewModel.isModelLoaded {
            OnboardingView(viewModel: viewModel)
        } else {
            VStack(spacing: 0) {
                personaBar
                messageList
                inputBar
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Barre personnalité

    private var personaBar: some View {
        HStack(spacing: 12) {
            Button {
                showingPersona = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.persona.icon)
                        .font(.caption)
                    Text(viewModel.persona.displayName)
                        .font(.caption.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            Spacer()

            Menu {
                ForEach(GenerationPreset.allCases, id: \.self) { preset in
                    Button {
                        viewModel.preset = preset
                        AppUtils.haptic(.light)
                    } label: {
                        Label(preset.displayName, systemImage: preset.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.preset.icon)
                        .font(.caption)
                    Text(viewModel.preset.displayName)
                        .font(.caption.bold())
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            if viewModel.tokensPerSecond > 0 && !viewModel.isGenerating {
                Text(AppUtils.formatSpeed(viewModel.tokensPerSecond))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Liste des messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let conv = viewModel.store.currentConversation {
                        ForEach(conv.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isGenerating && !viewModel.currentPartialResponse.isEmpty {
                        MessageRow(message: ChatMessage(
                            role: .assistant,
                            content: viewModel.currentPartialResponse
                        ))
                        .id("generating")
                    }

                    if viewModel.isGenerating && viewModel.currentPartialResponse.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Réflexion...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.store.currentConversation?.messages.count ?? 0) { _, _ in
                withAnimation {
                    if let lastId = viewModel.store.currentConversation?.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.currentPartialResponse) { _, _ in
                withAnimation {
                    proxy.scrollTo("generating", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Barre de saisie

    private var inputBar: some View {
        HStack(spacing: 12) {
            Button {
                toggleSpeechRecognition()
            } label: {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(isListening ? .red : .accentColor)
            }
            .disabled(!SpeechRecognizer.shared.isAvailable)

            TextField("Écrivez votre message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($inputFocused)

            if viewModel.isGenerating {
                Button {
                    viewModel.stopGeneration()
                    AppUtils.haptic(.medium)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                }
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .gray : .accentColor
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.sendMessage(text)
        inputText = ""
        AppUtils.haptic(.light)
    }

    private func toggleSpeechRecognition() {
        if isListening {
            SpeechRecognizer.shared.stop { text in
                if let text = text, !text.isEmpty {
                    inputText += text
                }
                isListening = false
                inputFocused = true
            }
        } else {
            SpeechRecognizer.shared.start { text in
                inputText = text
            }
            isListening = true
            AppUtils.haptic(.light)
        }
    }
}

// MARK: - Bulle de message

struct MessageRow: View {
    let message: ChatMessage
    @State private var showCopyToast = false

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundStyle(.accentColor)
                    }
                    Text(message.role.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    if let tps = message.tokensPerSecond {
                        Text(AppUtils.formatSpeed(tps))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if message.role == .user {
                    Text(message.content)
                        .font(.body)
                        .padding(12)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(16)
                } else {
                    Text(LocalizedStringKey(message.content))
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                }

                if message.role == .assistant && !message.content.isEmpty {
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = message.content
                            AppUtils.hapticSuccess()
                            withAnimation { showCopyToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopyToast = false }
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if showCopyToast {
                            Text("Copié")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        ShareLink(item: message.content) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            SpeechSynthesizer.shared.speak(message.content)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Onboarding (1-tap)

struct OnboardingView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 72))
                    .foregroundStyle(.accentColor)

                Text("Agent IA Local")
                    .font(.largeTitle.bold())

                Text("Assistant IA 100% privé sur votre iPhone.\nAucune donnée ne quitte votre appareil.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Info appareil + modèle
            VStack(spacing: 8) {
                Text(AppUtils.friendlyDeviceName)
                    .font(.headline)

                // Badge modèle préinstallé
                switch viewModel.recommendedModelLocation {
                case .bundled:
                    Label("Modèle inclus dans l'app", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                case .documents:
                    Label("Modèle déjà téléchargé", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                case .remote:
                    Label("Modèle à télécharger: \(viewModel.recommendedModel.name) (\(viewModel.recommendedModel.sizeLabel))", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Modèle recommandé: \(viewModel.recommendedModel.name)")
                    .font(.caption)
                    .foregroundStyle(.accentColor)
            }

            // Bouton principal
            VStack(spacing: 12) {
                Button {
                    AppUtils.haptic(.medium)
                    Task { await viewModel.quickStart() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoadingModel {
                            ProgressView()
                                .tint(.white)
                            Text(viewModel.loadStatus.isEmpty ? "Démarrage..." : viewModel.loadStatus)
                        } else {
                            // Icône différente selon le statut
                            switch viewModel.recommendedModelLocation {
                            case .bundled:
                                Image(systemName: "bolt.fill")
                                Text("Démarrer avec le modèle inclus")
                            case .documents:
                                Image(systemName: "bolt.fill")
                                Text("Démarrer avec le modèle installé")
                            case .remote:
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Installer et démarrer")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isLoadingModel)

                Button {
                    viewModel.showModelSheet = true
                } label: {
                    Text("Choisir un autre modèle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isLoadingModel {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.loadProgress)
                        if let dlState = viewModel.downloadManager.state(for: viewModel.recommendedModel.id),
                           dlState.totalBytes > 0 {
                            Text("\(AppUtils.formatBytes(dlState.downloadedBytes)) / \(AppUtils.formatBytes(dlState.totalBytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding(.horizontal, 32)

            // Liste des modèles préinstallés
            if !viewModel.installedModels.isEmpty {
                VStack(spacing: 8) {
                    Text("Modèles disponibles")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.installedModels) { model in
                        HStack(spacing: 8) {
                            Image(systemName: model.badge == "Inclus" ? "cube.fill" : "internaldrive")
                                .font(.caption)
                                .foregroundStyle(model.badge == "Inclus" ? .green : .blue)

                            Text(model.info.name)
                                .font(.caption)

                            Text(model.badge)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(model.badge == "Inclus" ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(model.badge == "Inclus" ? .green : .blue)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .sheet(isPresented: $viewModel.showModelSheet) {
            ModelListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Sidebar conversations

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.store.conversations.isEmpty {
                    Text("Aucune conversation")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.store.conversations) { conv in
                        Button {
                            viewModel.store.switchTo(conv.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conv.title)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.store.deleteConversation(id: conv.id)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _ = viewModel.store.createNewConversation()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
