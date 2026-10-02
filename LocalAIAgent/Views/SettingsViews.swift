import SwiftUI

// MARK: - Liste des modèles

struct ModelListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Modèles installés (bundle + documents)
                if !viewModel.installedModels.isEmpty {
                    Section("Installés") {
                        ForEach(viewModel.installedModels) { installed in
                            Button {
                                switch installed.location {
                                case .bundled(let url), .documents(let url):
                                    viewModel.loadExistingModel(at: url, info: installed.info)
                                    if viewModel.isModelLoaded { dismiss() }
                                case .remote:
                                    break
                                }
                            } label: {
                                InstalledModelRow(installed: installed, viewModel: viewModel)
                            }
                        }
                    }
                }

                // Modèles recommandés à télécharger
                Section("À télécharger") {
                    ForEach(ModelInfo.recommended.filter { model in
                        !viewModel.installedModels.contains(where: { $0.id == model.id })
                    }) { model in
                        ModelRow(model: model, viewModel: viewModel) {
                            Task {
                                await viewModel.downloadAndLoad(model: model)
                                if viewModel.isModelLoaded { dismiss() }
                            }
                        }
                    }
                }

                // Modèles avancés
                Section("Avancés") {
                    ForEach(ModelInfo.advanced) { model in
                        ModelRow(model: model, viewModel: viewModel) {
                            Task {
                                await viewModel.downloadAndLoad(model: model)
                                if viewModel.isModelLoaded { dismiss() }
                            }
                        }
                    }
                }

                Section {
                    Label("Les modèles « Inclus » sont préinstallés dans l'app.", systemImage: "cube.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Lancez scripts/download_bundled_models.sh pour préinstaller.", systemImage: "terminal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Modèles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                viewModel.refreshInstalledModels()
            }
        }
    }
}

// MARK: - Ligne modèle installé

struct InstalledModelRow: View {
    let installed: InstalledModel
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(installed.info.name)
                    .font(.headline)

                Text(installed.info.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Badge de localisation
                    Text(installed.badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(installed.badge == "Inclus" ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(installed.badge == "Inclus" ? .green : .blue)

                    Text(installed.info.sizeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.currentModelInfo?.id == installed.info.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ligne modèle à télécharger

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var viewModel: ChatViewModel
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.sizeLabel)
                        .font(.caption.bold())
                    Text("RAM: \(model.recommendedRAM) GB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: action) {
                HStack {
                    if let dlState = viewModel.downloadManager.state(for: model.id) {
                        if dlState.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Chargé")
                        } else {
                            ProgressView(value: dlState.progress)
                                .frame(maxWidth: 120)
                            Text("\(Int(dlState.progress * 100))%")
                                .font(.caption)
                        }
                    } else if viewModel.isLoadingModel && viewModel.loadStatus == model.id {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Téléchargement...")
                    } else {
                        Image(systemName: "arrow.down.circle")
                        Text(model.isChatML ? "Télécharger" : "Télécharger (avancé)")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(model.isChatML ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingModel)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Paramètres

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Modèle") {
                    HStack {
                        Text("Modèle actuel")
                        Spacer()
                        Text(viewModel.currentModelInfo?.name ?? "Aucun")
                            .foregroundStyle(.secondary)
                    }
                    Button("Décharger le modèle", role: .destructive) {
                        viewModel.unloadModel()
                    }
                }

                Section("Modèles installés") {
                    if viewModel.installedModels.isEmpty {
                        Text("Aucun modèle installé")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.installedModels) { installed in
                            HStack {
                                Text(installed.info.name)
                                Spacer()
                                Text(installed.badge)
                                    .font(.caption)
                                    .foregroundStyle(installed.badge == "Inclus" ? .green : .blue)
                            }
                        }
                    }
                }

                Section("Appareil") {
                    LabeledContent("Modèle", value: AppUtils.friendlyDeviceName)
                    LabeledContent("RAM estimée", value: "~\(viewModel.deviceRAM) GB")
                    LabeledContent("Modèle recommandé", value: viewModel.recommendedModel.name)
                }

                Section("À propos") {
                    Label("100% hors ligne", systemImage: "lock.shield")
                    Label("Aucune donnée envoyée", systemImage: "wifi.slash")
                    Label("Accélération Metal (GPU)", systemImage: "bolt.fill")
                    Label("Flash Attention activé", systemImage: "sparkles")
                    Label("KV Cache Q8 (mémoire optimisée)", systemImage: "memorychip")
                    Label("Modèles préinstallés supportés", systemImage: "cube.fill")
                    Label("Propulsé par llama.cpp", systemImage: "cpu")
                }

                Section("Données") {
                    Button("Effacer toutes les conversations", role: .destructive) {
                        viewModel.store.clearAll()
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sélecteur de personnalité

struct PersonaView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Personnalité") {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Button {
                            viewModel.persona = persona
                            AppUtils.haptic(.light)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: persona.icon.wrappedValue)
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.displayName)
                                        .font(.headline)
                                    Text(persona.systemPrompt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }

                                Spacer()

                                if viewModel.persona == persona {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Personnalité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
