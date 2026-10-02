#!/bin/bash
#
# Build un IPA NON SIGNÉ pour AltStore / Sideloadly / SideStore
#
# L'IPA non signé doit être installé avec un outil de sideloading:
#   - Sideloadly (Mac/Windows): https://sideloadly.io
#   - AltStore / SideStore: https://altstore.io
#   - Apple Configurator 2 (Mac App Store)
#
# Avec un Apple ID gratuit, l'app expire après 7 jours.
# Avec un compte Apple Developer (99$/an), validité 1 an.
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
DIST_DIR="$PROJECT_ROOT/dist"

cd "$PROJECT_ROOT"

# Vérifier le projet Xcode
if [ ! -d "LocalAIAgent.xcodeproj" ]; then
    print_err "Projet Xcode non trouvé."
    echo "  Lancez d'abord: ./scripts/generate_xcode_project.sh"
    exit 1
fi

# Vérifier Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_err "Xcode n'est pas installé. Installez Xcode depuis le Mac App Store."
    exit 1
fi

print_info "Build de l'IPA non signé..."
echo ""

# Build en Release sans signature
xcodebuild \
  -project LocalAIAgent.xcodeproj \
  -scheme LocalAIAgent \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tail -20

# Vérifier que le .app est généré
APP_PATH="build/Build/Products/Release-iphoneos/LocalAIAgent.app"
if [ ! -d "$APP_PATH" ]; then
    print_err "Build échoué — le .app n'a pas été généré"
    exit 1
fi

print_ok "Application compilée"
echo ""

# Créer l'IPA
print_info "Création de l'IPA..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/Payload"
cp -R "$APP_PATH" "$DIST_DIR/Payload/"

cd "$DIST_DIR"
zip -r "LocalAIAgent-unsigned.ipa" Payload -q
cd "$PROJECT_ROOT"

IPA_PATH="$DIST_DIR/LocalAIAgent-unsigned.ipa"
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)

print_ok "IPA créé: $IPA_PATH ($IPA_SIZE)"
echo ""
echo "=========================================="
echo "Installation sans Xcode:"
echo ""
echo "Option 1 — Sideloadly (recommandé, Mac/Windows):"
echo "  1. Téléchargez Sideloadly sur https://sideloadly.io"
echo "  2. Ouvrez Sideloadly"
echo "  3. Glissez LocalAIAgent-unsigned.ipa dans Sideloadly"
echo "  4. Entrez votre Apple ID"
echo "  5. Connectez votre iPhone et cliquez sur Start"
echo ""
echo "Option 2 — AltStore / SideStore:"
echo "  1. Installez AltStore sur votre Mac et iPhone"
echo "  2. Glissez l'IPA dans AltServer"
echo "  3. Suivez les instructions"
echo ""
echo "Option 3 — SideStore (alternative sans Mac):"
echo "  1. Installez SideStore sur votre iPhone (via AltStore ou jailbreak)"
echo "  2. Importez l'IPA dans SideStore"
echo "  3. Suivez les instructions"
echo ""
echo "⚠ Cet IPA est NON SIGNÉ. Il doit être signé par Sideloadly,"
echo "  AltStore ou SideStore avant installation."
echo "  Il ne peut PAS être installé directement via Apple Configurator,"
echo "  Diawi ou AirDrop. Pour cela, utilisez build_signed_ipa.sh."
echo ""
echo "⚠ Avec un Apple ID gratuit, l'app expire après 7 jours."
echo "  Re-sideloadez l'IPA pour la renouveler."
echo "=========================================="
