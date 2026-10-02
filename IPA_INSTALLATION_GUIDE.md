# Guide d'installation IPA — Agent IA Local

Ce guide explique comment créer et installer un fichier `.ipa` sur votre iPhone sans Xcode.

## Aperçu

Un fichier `.ipa` est une application iOS installable directement. Il existe deux méthodes selon votre compte:

| Méthode | Type d'IPA | Compte | Validité | Sans Mac ? |
|---------|-----------|--------|----------|------------|
| Sideloadly | Non signé | Apple ID gratuit | 7 jours | Non |
| AltStore | Non signé | Apple ID gratuit | 7 jours | Non |
| SideStore | Non signé | Apple ID gratuit | 7 jours | Oui |
| Apple Configurator 2 | Signé | Les deux | Variable | Non |
| Diawi (QR code) | Signé | Apple Developer | 1 an | Oui |
| AirDrop | Signé | Apple Developer | 1 an | Non |

---

## Étape 1: Préparation (sur Mac)

### Installer XcodeGen

```bash
brew install xcodegen
```

### Installer Xcode (si pas déjà fait)

Téléchargez Xcode depuis le Mac App Store (gratuit).

---

## Étape 2: Générer le projet Xcode

```bash
cd ios-local-ai-agent-v4
./scripts/generate_xcode_project.sh
```

Cela crée `LocalAIAgent.xcodeproj` automatiquement à partir de `project.yml`.

---

## Étape 3: Build l'IPA

### Option A: IPA non signé (Apple ID gratuit — recommandé)

```bash
./scripts/build_unsigned_ipa.sh
```

L'IPA est créé dans `dist/LocalAIAgent-unsigned.ipa`.

### Option B: IPA signé (compte Apple Developer)

```bash
# Trouvez votre Team ID dans Xcode → Settings → Accounts
DEVELOPMENT_TEAM=ABC12345 ./scripts/build_signed_ipa.sh
```

L'IPA est créé dans `dist/LocalAIAgent.ipa`.

---

## Étape 4: Installer sur l'iPhone

### Si vous avez un IPA NON SIGNÉ (build_unsigned_ipa.sh)

Un IPA non signé doit être signé par un outil de sideloading avant installation.

#### Méthode 1: Sideloadly (Mac/Windows — le plus simple)

1. Téléchargez [Sideloadly](https://sideloadly.io) et installez-le
2. Ouvrez Sideloadly
3. Glissez le fichier `.ipa` dans Sideloadly
4. Entrez votre Apple ID (email + mot de passe)
5. Connectez votre iPhone en USB
6. Cliquez sur **Start**
7. Sur l'iPhone: Réglages → Général → VPN et gestion des appareils → approuvez votre Apple ID

#### Méthode 2: AltStore (Mac)

1. Téléchargez [AltServer](https://altstore.io) et installez-le
2. Lancez AltServer (icône dans la barre de menus)
3. Connectez votre iPhone en USB
4. Cliquez sur AltServer → Install AltStore → votre iPhone
5. Sur le Mac: glissez le `.ipa` sur AltServer
6. Suivez les instructions

#### Méthode 3: SideStore (sans Mac)

1. Installez SideStore sur votre iPhone
2. Importez l'IPA dans SideStore
3. Suivez les instructions

### Si vous avez un IPA SIGNÉ (build_signed_ipa.sh)

Un IPA signé peut être installé directement.

#### Méthode 1: Apple Configurator 2 (Mac App Store — gratuit)

1. Téléchargez Apple Configurator 2 depuis le Mac App Store
2. Connectez votre iPhone en USB
3. Ouvrez Apple Configurator 2
4. Glissez le `.ipa` sur l'iPhone dans l'app
5. Cliquez sur **Add**

#### Méthode 2: Diawi (installation sans fil par QR code)

1. Allez sur [https://www.diawi.com](https://www.diawi.com)
2. Uploadez le fichier `.ipa` signé
3. Scannez le QR code avec votre iPhone
4. Tapez sur le lien → Installer

#### Méthode 3: AirDrop

1. AirDrop le `.ipa` depuis votre Mac vers l'iPhone
2. L'IPA signé peut être installé directement

#### Méthode 4: Sideloadly / AltStore

1. L'IPA signé fonctionne aussi avec ces outils (pas besoin de re-signer)

---

## Limitations

### Apple ID gratuit (non-payé)
- L'app expire après **7 jours**
- Maximum **3 apps sideloaded** simultanément
- Re-sideloadez l'IPA chaque semaine pour renouveler
- L'app doit être ouverte au moins une fois tous les 7 jours

### Compte Apple Developer (99$/an)
- Validité **1 an**
- Pas de limite d'apps
- Pas besoin de re-sideloader régulièrement

---

## Dépannage

### "App not installed" ou "Unable to verify"
- Réglages → Général → VPN et gestion des appareils → approuvez le certificat
- Vérifiez que la date/heure est en automatique

### Build échoué
- Vérifiez que Xcode est à jour (16+)
- `brew install xcodegen` doit être exécuté
- Le modèle GGUF doit être dans `LocalAIAgent/BundledModels/`

### Llama.cpp non trouvé
- Le projet Xcode doit avoir le package llama.cpp ajouté
- File → Add Package Dependencies → `https://github.com/ggml-org/llama.cpp`

### Code signing error
- Pour l'IPA non signé: utilisez `build_unsigned_ipa.sh` (pas le signé)
- Pour l'IPA signé: configurez votre compte dans Xcode → Settings → Accounts
