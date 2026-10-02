# Agent IA Local pour iPhone — v5 Multi-Plateforme

Assistant IA 100% local et privé pour iPhone, avec build IPA depuis **Windows, Linux et Mac**.

## Nouveautés v5

- **Build IPA depuis Windows** — script PowerShell qui utilise GitHub Actions (runner macOS cloud)
- **Build IPA depuis Linux** — script bash qui utilise GitHub Actions (runner macOS cloud)
- **Build IPA depuis Mac** — scripts natifs Xcode (inchangés)
- **GitHub Actions** — workflows automatiques pour build dans le cloud
- **Codemagic** — alternative cloud avec `codemagic.yaml`
- **Modèle préinstallé** — Qwen 3 0.6B inclus, téléchargé automatiquement pendant le build cloud

## Démarrage rapide selon votre OS

### Windows

```powershell
# Prérequis: GitHub CLI
winget install --id GitHub.cli
gh auth login

# Build l'IPA non signé (pour Sideloadly/AltStore)
.\scripts\build_ipa_windows.ps1
```

Pour un IPA signé depuis Windows, une configuration avancée avec secrets GitHub est nécessaire (certificat Apple). Voir [BUILD_IPA_WINDOWS.md](BUILD_IPA_WINDOWS.md).

### Linux

```bash
# Prérequis: GitHub CLI
sudo apt install gh  # Ubuntu/Debian
gh auth login

# Build l'IPA non signé
./scripts/build_ipa_linux.sh
```

Pour un IPA signé depuis Linux, une configuration avancée avec secrets GitHub est nécessaire. Voir [BUILD_IPA_LINUX.md](BUILD_IPA_LINUX.md).

### Mac

```bash
# Prérequis: Xcode + XcodeGen
brew install xcodegen

# Générer et build
./scripts/generate_xcode_project.sh
./scripts/build_unsigned_ipa.sh
```

Voir [IPA_INSTALLATION_GUIDE.md](IPA_INSTALLATION_GUIDE.md) pour le guide complet.

## Comment ça marche

Windows et Linux ne peuvent pas compiler d'app iOS localement (Xcode n'existe que sur Mac). La solution:

1. Vous poussez le code sur GitHub
2. Le script déclenche GitHub Actions sur un runner macOS cloud gratuit
3. Le runner macOS compile l'IPA (Xcode + XcodeGen + modèle GGUF)
4. Le script télécharge l'IPA généré sur votre machine

```
Windows/Linux → GitHub Actions (macOS cloud) → IPA téléchargé
```

## Scripts disponibles

| Script | OS | Description |
|--------|-----|-------------|
| `build_ipa_windows.ps1` | Windows | Build IPA via GitHub Actions |
| `build_ipa_linux.sh` | Linux | Build IPA via GitHub Actions |
| `generate_xcode_project.sh` | Mac | Génère le projet Xcode |
| `build_unsigned_ipa.sh` | Mac | Build IPA non signé |
| `build_signed_ipa.sh` | Mac | Build IPA signé |
| `download_bundled_models.sh` | Tous | Préinstalle des modèles GGUF |

## Workflows GitHub Actions

| Workflow | Description |
|----------|-------------|
| `build-unsigned-ipa.yml` | Build IPA non signé sur runner macOS |
| `build-signed-ipa.yml` | Build IPA signé (Team ID requis) |

Les workflows sont déclenchés manuellement depuis GitHub ou via les scripts Windows/Linux.

## Installation de l'IPA sur l'iPhone

### IPA non signé (Apple ID gratuit — validité 7 jours)

| Outil | Plateforme | Lien |
|-------|-----------|------|
| Sideloadly | Mac, Windows | [sideloadly.io](https://sideloadly.io) |
| AltStore | Mac | [altstore.io](https://altstore.io) |
| SideStore | iPhone | [sidestore.io](https://sidestore.io) |

### IPA signé (Apple Developer — validité 1 an)

| Outil | Méthode | Lien |
|-------|---------|------|
| Diawi | QR code sans fil | [diawi.com](https://www.diawi.com) |
| Apple Configurator 2 | USB | Mac App Store |
| AirDrop | Sans fil | Mac |

## Modèle préinstallé

Le modèle **Qwen 3 0.6B** (~440 MB) est inclus localement et téléchargé automatiquement par GitHub Actions pendant le build cloud. Le fichier `.gguf` est exclu de Git (`.gitignore`) car il dépasse la limite de 100 MB de GitHub.

Pour inclure le modèle 4B:
```powershell
# Windows
.\scripts\build_ipa_windows.ps1 -LargeModel
```
```bash
# Linux
./scripts/build_ipa_linux.sh --large
```

## Structure du projet

```
ios-local-ai-agent-v5/
├── .github/workflows/
│   ├── build-unsigned-ipa.yml         # Workflow IPA non signé
│   └── build-signed-ipa.yml           # Workflow IPA signé
├── .gitignore                         # Exclut .gguf, build, dist
├── codemagic.yaml                     # Alternative: Codemagic CI
├── project.yml                        # XcodeGen config
├── IPA_INSTALLATION_GUIDE.md         # Guide Mac
├── BUILD_IPA_WINDOWS.md               # Guide Windows
├── BUILD_IPA_LINUX.md                 # Guide Linux
├── scripts/
│   ├── build_ipa_windows.ps1          # Script Windows
│   ├── build_ipa_linux.sh             # Script Linux
│   ├── generate_xcode_project.sh      # Script Mac
│   ├── build_unsigned_ipa.sh          # Script Mac
│   ├── build_signed_ipa.sh            # Script Mac
│   ├── download_bundled_models.sh     # Script tous OS
│   ├── ExportOptions-development.plist
│   └── ExportOptions-ad-hoc.plist
├── LocalAIAgent/
│   ├── LocalAIAgentApp.swift
│   ├── Models/ChatModels.swift
│   ├── Services/{LlamaEngine,ChatViewModel,ConversationStore,DownloadManager,VoiceServices}.swift
│   ├── Views/{ChatView,SettingsViews}.swift
│   ├── Utilities/AppUtils.swift
│   └── BundledModels/
│       ├── README.md
│       └── Qwen_Qwen3-0.6B-Q4_K_M.gguf  # Modèle (~440 MB, local seulement)
└── README.md
```

## Sources

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — moteur d'inférence
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — génération de projet Xcode
- [GitHub Actions](https://docs.github.com/en/actions) — CI/CD cloud avec runners macOS
- [Codemagic](https://codemagic.io) — CI/CD mobile alternatif
- [Sideloadly](https://sideloadly.io) — sideloading d'IPA
- [AltStore](https://altstore.io) — installation alternative
- [Diawi](https://www.diawi.com) — installation OTA par QR code
- [GitHub CLI](https://cli.github.com) — outil en ligne de commande GitHub

## Licence

Projet libre. llama.cpp sous licence MIT.
