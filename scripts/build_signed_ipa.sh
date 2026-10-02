#!/bin/bash
#
# Build un IPA SIGNÉ pour installation directe sur iPhone
#
# Prérequis:
#   - Compte Apple Developer (99$/an) OU Apple ID gratuit
#   - Xcode installé avec votre compte configuré
#   - Équipe de développement dans Xcode → Settings → Accounts
#
# Usage:
#   ./scripts/build_signed_ipa.sh                              # Apple ID par défaut
#   DEVELOPMENT_TEAM=ABC12345 ./scripts/build_signed_ipa.sh    # Team ID explicite
#   BUNDLE_ID=com.moi.LocalAI ./scripts/build_signed_ipa.sh    # Bundle ID personnalisé
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
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions-development.plist"

# Variables (modifiables par l'utilisateur)
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
BUNDLE_ID="${BUNDLE_ID:-com.localai.LocalAIAgent}"

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

print_info "Build de l'IPA signé..."
echo ""

if [ -n "$DEVELOPMENT_TEAM" ]; then
    print_info "Équipe: $DEVELOPMENT_TEAM"
else
    print_warn "Aucune DEVELOPMENT_TEAM spécifiée."
    echo "  Définissez votre Team ID:"
    echo "  DEVELOPMENT_TEAM=ABC12345 ./scripts/build_signed_ipa.sh"
    echo "  (Trouvez votre Team ID dans Xcode → Settings → Accounts)"
    echo ""
    echo "  Tentative avec signature automatique..."
fi

echo ""
print_info "1/2 — Archive..."
echo ""

# Construire les arguments de signature
TEAM_ARGS=()
if [ -n "$DEVELOPMENT_TEAM" ]; then
    TEAM_ARGS=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

# Archive
xcodebuild archive \
  -project LocalAIAgent.xcodeproj \
  -scheme LocalAIAgent \
  -configuration Release \
  -archivePath build/LocalAIAgent.xcarchive \
  -allowProvisioningUpdates \
  "${TEAM_ARGS[@]}" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Automatic 2>&1 | tail -20

# Vérifier l'archive
if [ ! -d "build/LocalAIAgent.xcarchive" ]; then
    print_err "Archive échouée"
    exit 1
fi

print_ok "Archive créée"
echo ""
print_info "2/2 — Export IPA signé..."
echo ""

# Export
xcodebuild -exportArchive \
  -archivePath build/LocalAIAgent.xcarchive \
  -exportPath "$DIST_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates 2>&1 | tail -20

# Vérifier l'IPA
IPA_FILE="$DIST_DIR/LocalAIAgent.ipa"
if [ ! -f "$IPA_FILE" ]; then
    IPA_FILE=$(find "$DIST_DIR" -name "*.ipa" -print -quit 2>/dev/null)
fi

if [ -z "$IPA_FILE" ] || [ ! -f "$IPA_FILE" ]; then
    print_err "Export échoué — aucun IPA trouvé"
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)

print_ok "IPA signé créé: $IPA_FILE ($IPA_SIZE)"
echo ""
echo "=========================================="
echo "Installation sur iPhone:"
echo ""
echo "Option 1 — Apple Configurator 2:"
echo "  1. Connectez votre iPhone à votre Mac"
echo "  2. Ouvrez Apple Configurator 2 (Mac App Store)"
echo "  3. Glissez l'IPA sur l'iPhone"
echo ""
echo "Option 2 — Diawi (installation OTA par QR code):"
echo "  1. Allez sur https://www.diawi.com"
echo "  2. Uploadez l'IPA signé"
echo "  3. Scannez le QR code avec votre iPhone"
echo "  4. Installez directement — sans fil"
echo ""
echo "Option 3 — AirDrop:"
echo "  1. AirDrop l'IPA vers votre iPhone"
echo "  2. L'IPA signé peut être installé directement"
echo ""
echo "Option 4 — Sideloadly / AltStore:"
echo "  1. L'IPA signé fonctionne aussi avec ces outils"
echo ""
if [ -n "$DEVELOPMENT_TEAM" ]; then
    echo "✓ Avec un compte Apple Developer (99$/an), validité: 1 an"
else
    echo "⚠ Avec un Apple ID gratuit, validité: 7 jours"
fi
echo "=========================================="
