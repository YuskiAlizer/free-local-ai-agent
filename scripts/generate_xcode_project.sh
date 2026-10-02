#!/bin/bash
#
# Génère le projet Xcode à partir de project.yml (XcodeGen)
# À lancer sur Mac avant de build l'IPA
#
# Prérequis:
#   brew install xcodegen
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info()  { echo -e "${BLUE}ℹ $1${NC}"; }
print_ok()    { echo -e "${GREEN}✓ $1${NC}"; }
print_warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
print_err()   { echo -e "${RED}✗ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Vérifier xcodegen
if ! command -v xcodegen &> /dev/null; then
    print_err "XcodeGen n'est pas installé."
    echo ""
    echo "Installez-le avec Homebrew:"
    echo "  brew install xcodegen"
    echo ""
    exit 1
fi

# Vérifier le modèle préinstallé
if [ ! -f "LocalAIAgent/BundledModels/Qwen_Qwen3-0.6B-Q4_K_M.gguf" ]; then
    print_warn "Modèle préinstallé non trouvé."
    echo "  Lancez d'abord: ./scripts/download_bundled_models.sh"
    echo "  Le build fonctionnera mais sans modèle inclus."
    echo ""
else
    print_ok "Modèle Qwen 3 0.6B trouvé dans le bundle"
fi

print_info "Génération du projet Xcode..."

xcodegen generate

print_ok "Projet généré: LocalAIAgent.xcodeproj"
echo ""
echo "Vous pouvez maintenant:"
echo "  1. Ouvrir dans Xcode: open LocalAIAgent.xcodeproj"
echo "  2. Build un IPA: ./scripts/build_unsigned_ipa.sh"
echo "  3. Build un IPA signé: ./scripts/build_signed_ipa.sh"
