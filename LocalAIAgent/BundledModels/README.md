# Modèles préinstallés

Ce dossier contient les modèles GGUF préinstallés dans le bundle de l'app.

## Comment préinstaller un modèle

### Méthode 1: Script automatique (recommandé)

```bash
# Depuis la racine du projet:
./scripts/download_bundled_models.sh            # Qwen 3 0.6B seulement (~440 MB)
./scripts/download_bundled_models.sh --large    # + Qwen 3 4B (~2.5 GB)
./scripts/download_bundled_models.sh --all      # Tous les modèles recommandés
```

### Méthode 2: Manuel

1. Téléchargez un fichier `.gguf` depuis Hugging Face
2. Placez-le dans ce dossier `BundledModels/`
3. Nommez-le exactement comme dans `ModelInfo.bundleFileName`

## Noms de fichiers attendus

| Modèle | Nom de fichier |
|--------|---------------|
| Qwen 3 0.6B | `Qwen_Qwen3-0.6B-Q4_K_M.gguf` |
| Qwen 3 4B | `Qwen_Qwen3-4B-Q4_K_M.gguf` |

## Étape Xcode obligatoire

Après avoir placé les fichiers ici:

1. Ouvrez le projet Xcode
2. Glissez les fichiers `.gguf` dans le navigateur de projet (section `BundledModels`)
3. Cochez la cible `LocalAIAgent`
4. Vérifiez dans **Build Phases → Copy Bundle Resources** que les fichiers apparaissent
5. Compilez — les modèles seront inclus dans l'app

## Avantage

Les modèles préinstallés sont disponibles **immédiatement** au lancement de l'app, sans téléchargement. L'app les détecte automatiquement et les charge en priorité.
