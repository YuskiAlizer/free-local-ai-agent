#!/bin/bash
#
# Script de pré-installation des modèles GGUF dans le bundle de l'app.
#
# Usage:
#   ./scripts/download_bundled_models.sh           # Installe Qwen 3 0.6B (recommandé)
#   ./scripts/download_bundled_models.sh --large   # Installe aussi Qwen 3 4B
#   ./scripts/download_bundled_models.sh --all     # Installe tous les modèles recommandés
#
# Après exécution:
#   1. Ouvrez le projet Xcode
#   2. Glissez les fichiers .gguf du dossier BundledModels/ dans Xcode
#   3. Vérifiez qu'ils sont dans Build Phases → Copy Bundle Resources
#   4. Compilez — le modèle sera inclus dans l'app, disponible sans téléchargement

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUNDLED_DIR="$PROJECT_ROOT/LocalAIAgent/BundledModels"

mkdir -p "$BUNDLED_DIR"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_ok() { echo -e "${GREEN}✓ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Définition des modèles
# Compatible avec Bash 3.2 de macOS
get_model_url() {
    case "$1" in
        qwen3-0.6b)
            echo "https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
            ;;
        qwen3-4b)
            echo "https://huggingface.co/bartowski/Qwen_Qwen3-4B-GGUF/resolve/main/Qwen_Qwen3-4B-Q4_K_M.gguf"
            ;;
    esac
}

get_model_name() {
    case "$1" in
        qwen3-0.6b)
            echo "Qwen_Qwen3-0.6B-Q4_K_M.gguf"
            ;;
        qwen3-4b)
            echo "Qwen_Qwen3-4B-Q4_K_M.gguf"
            ;;
    esac
}

get_model_size() {
    case "$1" in
        qwen3-0.6b)
            echo "~440 MB"
            ;;
        qwen3-4b)
            echo "~2.5 GB"
            ;;
    esac
}

# Déterminer quels modèles installer
MODELS_TO_INSTALL=("qwen3-0.6b")

ARG="${1:-}"

if [ "$ARG" = "--large" ]; then
    MODELS_TO_INSTALL+=("qwen3-4b")
elif [ "$ARG" = "--all" ]; then
    MODELS_TO_INSTALL+=("qwen3-4b")
fi

print_info "Dossier de destination: $BUNDLED_DIR"
echo ""

# Télécharger chaque modèle
for model_id in "${MODELS_TO_INSTALL[@]}"; do
    url="$(get_model_url "$model_id")"
    filename="$(get_model_name "$model_id")"
    size="$(get_model_size "$model_id")"
    dest="$BUNDLED_DIR/$filename"

    if [ -f "$dest" ]; then
        print_warn "$filename déjà présent — ignoré ($size)"
        echo ""
        continue
    fi

    print_info "Téléchargement de $model_id ($size)..."
    echo "  URL: $url"
    echo ""

    # Téléchargement avec progression
    curl -L -o "$dest" -# "$url"

    if [ $? -eq 0 ]; then
        print_ok "$filename téléchargé avec succès"
    else
        print_warn "Échec du téléchargement de $model_id"
        rm -f "$dest"
    fi

    echo ""
done

# Résumé
echo "=========================================="
print_ok "Pré-installation terminée !"
echo ""
echo "Modèles dans le bundle:"
ls -lh "$BUNDLED_DIR"/*.gguf 2>/dev/null || echo "  (aucun)"
echo ""
echo "Prochaines étapes:"
echo "  1. Ouvrez le projet Xcode"
echo "  2. Vérifiez que les fichiers .gguf sont dans le projet"
echo "  3. Build Phases → Copy Bundle Resources doit contenir les .gguf"
echo "  4. Compilez et lancez sur votre iPhone"
echo ""
echo "Les modèles seront disponibles immédiatement au lancement de l'app."
echo "=========================================="
