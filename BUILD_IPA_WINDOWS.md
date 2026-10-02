# Build IPA depuis Windows

Windows ne peut pas compiler d'app iOS localement (Xcode n'existe que sur Mac). Ce guide utilise **GitHub Actions** avec un runner macOS cloud gratuit pour build l'IPA depuis Windows.

## Prérequis

### 1. Installer GitHub CLI

```powershell
winget install --id GitHub.cli
```

Ou téléchargez depuis [https://cli.github.com](https://cli.github.com)

### 2. Créer un compte GitHub (gratuit)

Si vous n'en avez pas: [https://github.com/signup](https://github.com/signup)

### 3. Authentifier GitHub CLI

```powershell
gh auth login
```

Suivez les instructions (GitHub.com → HTTPS → Yes → Login with a web browser).

## Build de l'IPA

### Option A: IPA non signé (Apple ID gratuit — pour Sideloadly/AltStore)

```powershell
.\scripts\build_ipa_windows.ps1
```

Le script:
1. Déclenche un build sur GitHub Actions (runner macOS cloud)
2. Attend la completion (5-15 minutes)
3. Télécharge l'IPA dans `dist/LocalAIAgent-unsigned.ipa`

### Option B: IPA signé (compte Apple Developer)

```powershell
.\scripts\build_ipa_windows.ps1 -Signed -TeamId ABC12345
```

Remplacez `ABC12345` par votre Team ID (disponible sur [developer.apple.com](https://developer.apple.com/account)).

### Option C: Inclure le modèle 4B

```powershell
.\scripts\build_ipa_windows.ps1 -LargeModel
# ou signé:
.\scripts\build_ipa_windows.ps1 -Signed -TeamId ABC12345 -LargeModel
```

## Build manuel (sans le script)

Si vous préférez lancer les commandes manuellement:

```powershell
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
$runId = gh run list --workflow build-unsigned-ipa.yml --limit 1 --json databaseId -q ".[0].databaseId"
gh run download $runId --name LocalAIAgent-unsigned-ipa --dir dist
```

## Installation de l'IPA sur l'iPhone

### IPA non signé
- **Sideloadly** — [https://sideloadly.io](https://sideloadly.io) (Mac ou Windows)
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
Relancez votre terminal après l'installation de GitHub CLI.

### "gh auth status: not logged in"
Exécutez `gh auth login` et suivez les instructions.

### Build échoué sur GitHub Actions
Consultez les logs: `gh run view --log`
Vérifiez que tous les scripts sont exécutables: `git update-index --chmod=+x scripts/*.sh`

### "artifact not found"
Attendez quelques secondes après la fin du build, le temps que l'artifact soit disponible.
