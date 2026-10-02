#!/bin/bash
#
# Build l'IPA de l'Agent IA Local depuis Linux via GitHub Actions.
#
# Linux ne peut pas compiler d'app iOS localement (Xcode requis).
# Ce script déclenche GitHub Actions sur un runner macOS cloud gratuit,
# attend la completion, puis télécharge l'IPA généré localement.
#
# Prérequis: GitHub CLI (gh) installé et authentifié.
#   Ubuntu/Debian: sudo apt install gh
#   Fedora: sudo dnf install gh
#   Arch: sudo pacman -S github-cli
#   Puis: gh auth login
#
# Usage:
#   ./scripts/build_ipa_linux.sh                    # IPA non signé
#   ./scripts/build_ipa_linux.sh --signed --team ABC12345  # IPA signé
#   ./scripts/build_ipa_linux.sh --large            # Inclure Qwen 3 4B
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()  { echo -e "${BLUE}ℹ $1${NC}"; }
print_ok()    { echo -e "${GREEN}✓ $1${NC}"; }
print_warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
print_err()   { echo -e "${RED}✗ $1${NC}"; }
print_cyan()  { echo -e "${CYAN}$1${NC}"; }

echo ""
print_cyan "=========================================="
print_cyan "  Agent IA Local — Build IPA depuis Linux"
print_cyan "=========================================="
echo ""

# Parser les arguments
SIGNED=false
LARGE_MODEL=false
TEAM_ID=""
BUNDLE_ID="com.localai.LocalAIAgent"

while [[ $# -gt 0 ]]; do
    case $1 in
        --signed)
            SIGNED=true
            shift
            ;;
        --large)
            LARGE_MODEL=true
            shift
            ;;
        --team)
            TEAM_ID="$2"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        *)
            print_err "Argument inconnu: $1"
            echo "Usage: $0 [--signed] [--large] [--team TEAM_ID] [--bundle-id BUNDLE_ID]"
            exit 1
            ;;
    esac
done

# Vérifier GitHub CLI
if ! command -v gh &> /dev/null; then
    print_err "GitHub CLI (gh) n'est pas installé."
    echo ""
    echo "Installation:"
    echo "  Ubuntu/Debian: sudo apt install gh"
    echo "  Fedora:        sudo dnf install gh"
    echo "  Arch:          sudo pacman -S github-cli"
    echo "  Autre:         https://cli.github.com"
    echo ""
    echo "Puis authentifiez-vous:"
    echo "  gh auth login"
    echo ""
    exit 1
fi

# Vérifier l'authentification
if ! gh auth status &> /dev/null; then
    print_err "Vous n'êtes pas connecté à GitHub."
    echo ""
    print_warn "Exécutez: gh auth login"
    echo ""
    exit 1
fi

print_ok "Connecté à GitHub."

# Vérifier que le dossier est dans un repo GitHub
if ! gh repo view &> /dev/null; then
    echo ""
    print_err "Ce dossier n'est pas dans un dépôt GitHub."
    echo ""
    print_warn "Vous devez d'abord pousser le code sur GitHub:"
    echo "  git init"
    echo "  git add ."
    echo "  git commit -m 'Initial commit'"
    echo "  git remote add origin https://github.com/VOTRE_USER/local-ai-agent.git"
    echo "  git push -u origin main"
    echo ""
    exit 1
fi

print_ok "Dépôt GitHub détecté."
echo ""

# Déterminer le workflow et déclencher le build
if $SIGNED; then
    if [ -z "$TEAM_ID" ]; then
        print_err "Pour un IPA signé, spécifiez votre Team ID:"
        echo "  $0 --signed --team ABC12345"
        echo ""
        echo "Trouvez votre Team ID sur https://developer.apple.com/account"
        exit 1
    fi
    WORKFLOW="build-signed-ipa.yml"
    print_ok "Type: IPA SIGNÉ (compte Apple Developer)"
    print_info "Team ID: $TEAM_ID"
    print_info "Bundle ID: $BUNDLE_ID"

    gh workflow run "$WORKFLOW" \
        -f development_team="$TEAM_ID" \
        -f bundle_id="$BUNDLE_ID" \
        -f large_model="$LARGE_MODEL"
else
    WORKFLOW="build-unsigned-ipa.yml"
    print_ok "Type: IPA NON SIGNÉ (pour Sideloadly/AltStore)"

    gh workflow run "$WORKFLOW" -f large_model="$LARGE_MODEL"
fi

if [ $? -ne 0 ]; then
    print_err "Échec du déclenchement du workflow."
    exit 1
fi

echo ""
print_ok "Build déclenché sur GitHub Actions (runner macOS)."
echo ""

# Attendre que le run apparaisse
sleep 5

# Surveiller le run
print_cyan "Surveillance du build en cours..."
print_warn "(Cela peut prendre 5-15 minutes)"
echo ""

gh run watch --workflow "$WORKFLOW" --exit-status 2>&1 | while read -r line; do
    echo "$line"
done

if [ $? -ne 0 ]; then
    echo ""
    print_err "Le build a échoué."
    print_warn "Consultez les logs: gh run view --log"
    exit 1
fi

echo ""
print_ok "Build terminé avec succès !"
echo ""

# Télécharger l'artifact
ARTIFACT_NAME="LocalAIAgent-unsigned-ipa"
if $SIGNED; then
    ARTIFACT_NAME="LocalAIAgent-signed-ipa"
fi

DEST_DIR="dist"
mkdir -p "$DEST_DIR"

print_cyan "Téléchargement de l'IPA..."

RUN_ID=$(gh run list --workflow "$WORKFLOW" --limit 1 --json databaseId -q '.[0].databaseId')
gh run download "$RUN_ID" --name "$ARTIFACT_NAME" --dir "$DEST_DIR"

echo ""
print_ok "=========================================="
print_ok "  IPA téléchargé dans: $DEST_DIR/"
print_ok "=========================================="
echo ""

if $SIGNED; then
    echo "Installation de l'IPA signé:"
    echo "  - Apple Configurator 2 (Mac)"
    echo "  - Diawi (QR code, sans fil: https://www.diawi.com)"
    echo "  - AirDrop vers iPhone"
    echo "  - Sideloadly / AltStore"
else
    echo "Installation de l'IPA non signé:"
    echo "  - Sideloadly (https://sideloadly.io)"
    echo "  - AltStore (https://altstore.io)"
    echo "  - SideStore"
    echo ""
    print_warn "Apple ID gratuit = validité 7 jours"
fi
echo ""
