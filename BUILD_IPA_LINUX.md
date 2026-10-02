# Build IPA depuis Linux

Linux ne peut pas compiler d'app iOS localement (Xcode n'existe que sur Mac). Ce guide utilise **GitHub Actions** avec un runner macOS cloud gratuit pour build l'IPA depuis Linux.

## Prérequis

### 1. Installer GitHub CLI

```bash
# Ubuntu / Debian
sudo apt install gh

# Fedora
sudo dnf install gh

# Arch Linux
sudo pacman -S github-cli

# Autres distributions: https://github.com/cli/cli#installation
```

### 2. Créer un compte GitHub (gratuit)

Si vous n'en avez pas: [https://github.com/signup](https://github.com/signup)

### 3. Authentifier GitHub CLI

```bash
gh auth login
```

Suivez les instructions (GitHub.com → HTTPS → Yes → Login with a web browser).

## Build de l'IPA

### Option A: IPA non signé (Apple ID gratuit — pour Sideloadly/AltStore)

```bash
./scripts/build_ipa_linux.sh
```

Le script:
1. Déclenche un build sur GitHub Actions (runner macOS cloud)
2. Attend la completion (5-15 minutes)
3. Télécharge l'IPA dans `dist/LocalAIAgent-unsigned.ipa`

### Option B: IPA signé (compte Apple Developer)

```bash
./scripts/build_ipa_linux.sh --signed --team ABC12345
```

Remplacez `ABC12345` par votre Team ID (disponible sur [developer.apple.com](https://developer.apple.com/account)).

### Option C: Inclure le modèle 4B

```bash
./scripts/build_ipa_linux.sh --large
# ou signé:
./scripts/build_ipa_linux.sh --signed --team ABC12345 --large
```

## Build manuel (sans le script)

Si vous préférez lancer les commandes manuellement:

```bash
# 1. Pousser le code sur GitHub
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/VOTRE_USER/local-ai-agent.git
git push -u origin main

# 2. Déclencher le workflow
gh workflow run build-unsigned-ipa.yml

# 3. Surveiller le build
gh run watch

# 4. Télécharger l'IPA
RUN_ID=$(gh run list --workflow build-unsigned-ipa.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run download "$RUN_ID" --name LocalAIAgent-unsigned-ipa --dir dist
```

## Alternative: Codemagic

Au lieu de GitHub Actions, vous pouvez utiliser [Codemagic](https://codemagic.io):

1. Connectez-vous sur codemagic.io avec votre compte GitHub
2. Ajoutez ce dépôt
3. Le fichier `codemagic.yaml` configure automatiquement le build
4. Cliquez sur "Start new build"
5. Téléchargez l'IPA à la fin

Codemagic offre 500 minutes/mois gratuites pour les dépôts publics.

## Installation de l'IPA sur l'iPhone

### IPA non signé
- **Sideloadly** — [https://sideloadly.io](https://sideloadly.io) (Mac, Windows, Linux via Wine)
- **AltStore** — [https://altstore.io](https://altstore.io) (Mac)
- **SideStore** — installation sur l'iPhone directement

### IPA signé
- **Diawi** — [https://www.diawi.com](https://www.diawi.com) (QR code, sans fil)
- **Apple Configurator 2** (Mac)
- **AirDrop** vers iPhone

## Limitations

- **Apple ID gratuit**: l'app expire après 7 jours, 3 apps max
- **GitHub Actions gratuit**: 2000 minutes/mois (un build = ~15 minutes)
- **Runner macOS**: macOS 14 (Sonoma) avec Xcode 16
- Le modèle GGUF (440 MB) est téléchargé pendant le build, pas stocké sur Git

## Dépannage

### "gh: command not found"
Installez GitHub CLI selon votre distribution (voir ci-dessus).

### "gh auth status: not logged in"
Exécutez `gh auth login` et suivez les instructions.

### Build échoué sur GitHub Actions
Consultez les logs: `gh run view --log`
Vérifiez que tous les scripts sont exécutables:
```bash
git update-index --chmod=+x scripts/*.sh
git commit -m "Fix script permissions"
git push
```

### "artifact not found"
Attendez quelques secondes après la fin du build, le temps que l'artifact soit disponible.

### Sideloadly sur Linux
Sideloadly n'existe pas nativement sur Linux. Utilisez SideStore sur l'iPhone, ou utilisez Wine pour faire tourner Sideloadly Windows.
