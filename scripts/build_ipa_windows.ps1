<#
.SYNOPSIS
    Build l'IPA de l'Agent IA Local depuis Windows via GitHub Actions.
.DESCRIPTION
    Ce script déclenche un build sur GitHub Actions (runner macOS cloud),
    attend la completion, puis télécharge l'IPA généré localement.
    Prérequis: GitHub CLI (gh) installé et authentifié.
.NOTES
    Windows ne peut pas compiler d'app iOS localement (Xcode requis).
    Ce script utilise GitHub Actions avec un runner macOS gratuit.
#>

param(
    [switch]$LargeModel,
    [switch]$Signed,
    [string]$TeamId = "",
    [string]$BundleId = "com.localai.LocalAIAgent"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Agent IA Local — Build IPA depuis Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier GitHub CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) n'est pas installé." -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation:" -ForegroundColor Yellow
    Write-Host "  winget install --id GitHub.cli"
    Write-Host "  # ou téléchargez: https://cli.github.com"
    Write-Host ""
    Write-Host "Puis authentifiez-vous:" -ForegroundColor Yellow
    Write-Host "  gh auth login"
    Write-Host ""
    exit 1
}

# Vérifier l'authentification
$authResult = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Vous n'êtes pas connecté à GitHub." -ForegroundColor Red
    Write-Host ""
    Write-Host "Exécutez: gh auth login" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Connecté à GitHub." -ForegroundColor Green

# Vérifier que le dossier est dans un repo GitHub
gh repo view 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Ce dossier n'est pas dans un dépôt GitHub." -ForegroundColor Red
    Write-Host ""
    Write-Host "Vous devez d'abord pousser le code sur GitHub:" -ForegroundColor Yellow
    Write-Host "  git init" -ForegroundColor White
    Write-Host "  git add ." -ForegroundColor White
    Write-Host "  git commit -m "Initial commit"" -ForegroundColor White
    Write-Host "  git remote add origin https://github.com/VOTRE_USER/local-ai-agent.git" -ForegroundColor White
    Write-Host "  git push -u origin main" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "Dépôt GitHub détecté." -ForegroundColor Green
Write-Host ""

# Déterminer le workflow
if ($Signed) {
    if ([string]::IsNullOrWhiteSpace($TeamId)) {
        Write-Host "Pour un IPA signé, spécifiez votre Team ID:" -ForegroundColor Red
        Write-Host "  .\build_ipa_windows.ps1 -Signed -TeamId ABC12345" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Trouvez votre Team ID dans Xcode > Settings > Accounts" -ForegroundColor Yellow
        Write-Host "ou sur https://developer.apple.com/account" -ForegroundColor Yellow
        exit 1
    }
    $workflow = "build-signed-ipa.yml"
    Write-Host "Type: IPA SIGNÉ (compte Apple Developer)" -ForegroundColor Green
    Write-Host "Team ID: $TeamId" -ForegroundColor Green
    Write-Host "Bundle ID: $BundleId" -ForegroundColor Green

    $large = $LargeModel.IsPresent.ToString().ToLower()
    $result = gh workflow run $workflow `
        -f development_team=$TeamId `
        -f bundle_id=$BundleId `
        -f large_model=$large
} else {
    $workflow = "build-unsigned-ipa.yml"
    Write-Host "Type: IPA NON SIGNÉ (pour Sideloadly/AltStore)" -ForegroundColor Green

    $large = $LargeModel.IsPresent.ToString().ToLower()
    $result = gh workflow run $workflow -f large_model=$large
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Échec du déclenchement du workflow." -ForegroundColor Red
    Write-Host $result
    exit 1
}

Write-Host ""
Write-Host "Build déclenché sur GitHub Actions (runner macOS)." -ForegroundColor Green
Write-Host ""

# Attendre quelques secondes pour que le run apparaisse
Start-Sleep -Seconds 5

# Surveiller le run
Write-Host "Surveillance du build en cours..." -ForegroundColor Cyan
Write-Host "(Cela peut prendre 5-15 minutes)" -ForegroundColor Yellow
Write-Host ""

gh run watch --workflow $workflow --exit-status 2>&1 | ForEach-Object {
    Write-Host $_
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Le build a échoué." -ForegroundColor Red
    Write-Host "Consultez les logs: gh run view --log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Build terminé avec succès !" -ForegroundColor Green
Write-Host ""

# Télécharger l'artifact
$artifactName = if ($Signed) { "LocalAIAgent-signed-ipa" } else { "LocalAIAgent-unsigned-ipa" }
$destDir = "dist"

if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

Write-Host "Téléchargement de l'IPA..." -ForegroundColor Cyan

$runId = gh run list --workflow $workflow --limit 1 --json databaseId -q ".[0].databaseId"
gh run download $runId --name $artifactName --dir $destDir

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  IPA téléchargé dans le dossier: $destDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

if ($Signed) {
    Write-Host "Installation de l'IPA signé:" -ForegroundColor White
    Write-Host "  - Apple Configurator 2 (Mac)"
    Write-Host "  - Diawi (QR code, sans fil)"
    Write-Host "  - AirDrop vers iPhone"
    Write-Host "  - Sideloadly / AltStore"
} else {
    Write-Host "Installation de l'IPA non signé:" -ForegroundColor White
    Write-Host "  - Sideloadly (https://sideloadly.io)"
    Write-Host "  - AltStore (https://altstore.io)"
    Write-Host "  - SideStore"
    Write-Host ""
    Write-Host "ATTENTION: Apple ID gratuit = validité 7 jours" -ForegroundColor Yellow
}
Write-Host ""
