<#
.SYNOPSIS
  Heuristiques Architecture Review DVCR (filet automatique).

.DESCRIPTION
  Ne remplace PAS la checklist humaine : ../ARCHITECTURE_REVIEW.md
  App cible (ADR-0004) : racine dvcr_appli (pubspec.yaml + lib/), PAS dvcr-v2/app.

  In-place modernization (ADR-0004) :
  - FAIL stricts ciblent le code modernisé (core/, shared/, features/*/data|domain|presentation)
  - Legacy (screens/, services/, models/, widgets/, ...) → WARN ou ignoré (pas FAIL massif)
  - GoRouter pas encore déployé → Navigator.push = WARN hors zones modernes

.PARAMETER AppRoot
  Racine du projet Flutter (dossier contenant pubspec.yaml).
  Defaut : parent de dvcr-v2/ (= racine dvcr_appli).

.PARAMETER StrictFeatures
  Si true, applique aussi les FAIL stricts a features/*/data|domain|presentation.
  Defaut false : ces dossiers hybrides existants (ex. prono) restent en WARN
  jusqu'au module Feature First correspondant (ADR-0004 - code touche).

.EXAMPLE
  .\architecture_review.ps1
  .\architecture_review.ps1 -AppRoot ..
  .\architecture_review.ps1 -StrictFeatures  # lors d'un module feature
#>
[CmdletBinding()]
param(
  [string]$AppRoot = "",
  [switch]$StrictFeatures
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DvcrV2Root = (Resolve-Path (Join-Path $ScriptDir "..")).Path

if ([string]::IsNullOrWhiteSpace($AppRoot)) {
  # Modernisation in-place : app = monorepo root (parent de dvcr-v2/)
  $AppRoot = Join-Path $DvcrV2Root ".."
}

$AppRoot = (Resolve-Path -LiteralPath $AppRoot).Path
$Pubspec = Join-Path $AppRoot "pubspec.yaml"
$LibRoot = Join-Path $AppRoot "lib"

Write-Host "=== DVCR Architecture Review (heuristiques) ===" -ForegroundColor Cyan
Write-Host "AppRoot : $AppRoot"
Write-Host ("Mode    : in-place (ADR-0004) - StrictFeatures={0}" -f $StrictFeatures.IsPresent)
Write-Host "Checklist humaine obligatoire : dvcr-v2/ARCHITECTURE_REVIEW.md"
Write-Host ""

if (-not (Test-Path -LiteralPath $Pubspec)) {
  Write-Host "FAIL: aucun pubspec.yaml sous '$AppRoot'." -ForegroundColor Red
  Write-Host "Attendu : racine dvcr_appli. Exemple : .\architecture_review.ps1 -AppRoot .."
  Write-Host "Exit code 2 - app absente."
  exit 2
}

if (-not (Test-Path -LiteralPath $LibRoot)) {
  Write-Host "FAIL: pubspec.yaml present mais dossier lib/ absent." -ForegroundColor Red
  exit 1
}

# Stack de base (PACKAGE_POLICY) - noms pubspec approximatifs
$AllowedDirectDeps = @(
  "flutter",
  "flutter_test",
  "flutter_lints",
  "firebase_core",
  "firebase_auth",
  "cloud_firestore",
  "firebase_storage",
  "firebase_messaging",
  "cloud_functions",
  "flutter_riverpod",
  "riverpod",
  "hooks_riverpod",
  "go_router",
  "dio",
  "freezed_annotation",
  "json_annotation",
  "json_serializable",
  "freezed",
  "build_runner",
  "cupertino_icons",
  "meta",
  "collection",
  "equatable",
  "fake_cloud_firestore",
  "firebase_auth_mocks",
  "integration_test",
  "path",
  "intl",
  "shared_preferences",
  "google_fonts",
  "http"
)

$script:Fails = New-Object System.Collections.Generic.List[string]
$script:Warns = New-Object System.Collections.Generic.List[string]

function Get-DartFiles {
  param([string]$Root)
  if (-not (Test-Path -LiteralPath $Root)) {
    return @()
  }
  Get-ChildItem -LiteralPath $Root -Recurse -Filter *.dart -File |
    Where-Object {
      ($_.Name -notmatch '\.(freezed|g)\.dart$') -and
      ($_.FullName -notmatch '[\\/]generated[\\/]')
    }
}

function Add-Fail {
  param([string]$Message)
  $script:Fails.Add($Message) | Out-Null
}

function Add-Warn {
  param([string]$Message)
  $script:Warns.Add($Message) | Out-Null
}

function Test-IsModernizedPath {
  param([string]$Rel)
  # Foundation zones always strict
  if ($Rel -match '(?i)^lib[/\\]core[/\\]') { return $true }
  if ($Rel -match '(?i)^lib[/\\]shared[/\\]') { return $true }
  # Feature layered paths: strict only with -StrictFeatures (module feature)
  if ($StrictFeatures -and ($Rel -match '(?i)^lib[/\\]features[/\\][^/\\]+[/\\](data|domain|presentation)[/\\]')) {
    return $true
  }
  return $false
}

function Test-IsLegacyPath {
  param([string]$Rel)
  if ($Rel -match '(?i)^lib[/\\](screens|services|models|widgets|utils|app|navigation|theme)[/\\]') {
    return $true
  }
  # Feature files not yet under data/domain/presentation (legacy hybrid)
  if ($Rel -match '(?i)^lib[/\\]features[/\\]') {
    if (-not (Test-IsModernizedPath -Rel $Rel)) {
      return $true
    }
  }
  return $false
}

# Regex import Dart: import '...' ou import "..."
$sq = [char]39
$dq = [char]34
$ImportRegex = [regex]("import\s+[${sq}${dq}]([^${sq}${dq}]+)[${sq}${dq}]")

foreach ($file in (Get-DartFiles -Root $LibRoot)) {
  $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if ([string]::IsNullOrEmpty($text)) {
    continue
  }
  $rel = $file.FullName.Substring($AppRoot.Length).TrimStart('\', '/')
  $isModern = Test-IsModernizedPath -Rel $rel
  $isLegacy = Test-IsLegacyPath -Rel $rel

  $srcFeature = $null
  if ($rel -match 'features[/\\]([^/\\]+)[/\\]') {
    $srcFeature = $Matches[1]
  }

  foreach ($m in $ImportRegex.Matches($text)) {
    $imp = $m.Groups[1].Value
    if ($imp -notmatch 'features/') {
      continue
    }
    if ($imp -match 'features/([^/]+)/(.+)') {
      $tgtFeature = $Matches[1]
      $rest = $Matches[2]
      if (($null -ne $srcFeature) -and ($srcFeature -ne $tgtFeature)) {
        if ($rest -eq ($tgtFeature + '.dart')) {
          continue
        }
        # Cross-feature deep imports: FAIL only when introduced from modernized paths
        if ($isModern) {
          Add-Fail ("Import croise : {0} importe features/{1}/{2} (depuis features/{3})" -f $rel, $tgtFeature, $rest, $srcFeature)
        }
        else {
          Add-Warn ("Import croise legacy : {0} importe features/{1}/{2}" -f $rel, $tgtFeature, $rest)
        }
      }
    }
  }

  if ($rel -match 'features[/\\](world_cup|esti|esti_dvcr|tournaments)([/\\]|$)') {
    # Existing event surfaces are debt - do not FAIL the whole repo (ADR-0004).
    # FAIL only if they appear under core/ (industrialisation).
    if ($rel -match '(?i)^lib[/\\]core[/\\]') {
      Add-Fail ("Feature evenementielle industrialisee dans core : {0} (ADR-0002)" -f $rel)
    }
    else {
      Add-Warn ("Surface evenementielle legacy : {0} (ADR-0002 - ne pas industrialiser)" -f $rel)
    }
  }

  # Firestore / Dio in presentation / domain: FAIL only when -StrictFeatures
  if ($rel -match 'features[/\\][^/\\]+[/\\]presentation[/\\]') {
    if (($text -match 'FirebaseFirestore') -or ($text -match '\.collection\s*\(')) {
      if ($StrictFeatures) {
        Add-Fail ("Firestore dans presentation : {0}" -f $rel)
      }
      else {
        Add-Warn ("Firestore dans presentation (hybride) : {0}" -f $rel)
      }
    }
    if (($text -match 'package:dio/') -or ($text -match '\bDio\b')) {
      if ($StrictFeatures) {
        Add-Fail ("Dio dans presentation : {0}" -f $rel)
      }
      else {
        Add-Warn ("Dio dans presentation (hybride) : {0}" -f $rel)
      }
    }
  }
  elseif (($rel -match '[/\\]widgets[/\\]') -and -not $isModern) {
    if (($text -match 'FirebaseFirestore') -or ($text -match '\.collection\s*\(')) {
      Add-Warn ("Firestore dans widgets legacy : {0}" -f $rel)
    }
  }

  if ($rel -match 'features[/\\][^/\\]+[/\\]domain[/\\]') {
    if (($text -match 'cloud_firestore') -or ($text -match 'FirebaseFirestore')) {
      if ($StrictFeatures) {
        Add-Fail ("Firestore dans domain : {0}" -f $rel)
      }
      else {
        Add-Warn ("Firestore dans domain (hybride) : {0}" -f $rel)
      }
    }
    if (($text -match 'package:flutter/material\.dart') -or ($text -match 'package:flutter/widgets\.dart')) {
      if ($StrictFeatures) {
        Add-Fail ("Widgets Flutter dans domain : {0}" -f $rel)
      }
      else {
        Add-Warn ("Widgets Flutter dans domain (hybride) : {0}" -f $rel)
      }
    }
  }

  if ($text -match 'Navigator\s*\.\s*push') {
    if ($isModern) {
      # GoRouter not introduced yet (Foundation OUT) - soft until router module
      Add-Warn ("Navigator.push dans zone modernisee : {0} (migrer vers GoRouter au module Navigation)" -f $rel)
    }
    elseif (-not $isLegacy) {
      Add-Warn ("Navigator.push : {0}" -f $rel)
    }
  }

  if (($text -match '\bCSSA\b') -or ($text -match '\bClub Sportif Sedan\b') -or ($text -match '(?i)sedanais')) {
    if (($rel -notmatch 'test[/\\]') -and ($rel -notmatch 'fixture')) {
      if ($isModern) {
        Add-Fail ("Hardcode club dans zone modernisee : {0} (TenantConfig)" -f $rel)
      }
      else {
        Add-Warn ("Possible hardcode club dans {0} - verifier TenantConfig" -f $rel)
      }
    }
  }

  $setStateCount = ([regex]::Matches($text, '\bsetState\s*\(')).Count
  if ($setStateCount -ge 5) {
    if ($isModern) {
      Add-Warn ("setState frequent ({0}) dans zone modernisee {1} - OK si UI locale ; FAIL si etat metier" -f $setStateCount, $rel)
    }
    elseif (-not $isLegacy) {
      Add-Warn ("setState frequent ({0}) dans {1}" -f $setStateCount, $rel)
    }
  }

  $lineCount = @(Get-Content -LiteralPath $file.FullName).Count
  if ($lineCount -gt 300) {
    if ($isModern) {
      Add-Fail ("Fichier > 300 lignes ({0}) : {1}" -f $lineCount, $rel)
    }
    # Legacy oversized files: ignored (debt planned, not Foundation scope)
  }
}

foreach ($layer in @('core', 'shared')) {
  $layerRoot = Join-Path $LibRoot $layer
  foreach ($file in (Get-DartFiles -Root $layerRoot)) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    $rel = $file.FullName.Substring($AppRoot.Length).TrimStart('\', '/')
    foreach ($m in $ImportRegex.Matches($text)) {
      $imp = $m.Groups[1].Value
      if ($imp -match 'features/') {
        Add-Fail ("{0} importe features : {1} -> {2}" -f $layer, $rel, $imp)
      }
    }
  }
}

# Foundation bootstrap: ProviderScope expected once Riverpod is in pubspec
try {
  $pubText = Get-Content -LiteralPath $Pubspec -Raw
  if ($pubText -match 'flutter_riverpod') {
    $mainPath = Join-Path $LibRoot "main.dart"
    if (Test-Path -LiteralPath $mainPath) {
      $mainText = Get-Content -LiteralPath $mainPath -Raw
      if ($mainText -notmatch 'ProviderScope') {
        Add-Fail "flutter_riverpod present but ProviderScope missing in lib/main.dart (Foundation)"
      }
    }
  }

  $sectionDeps = [regex]::Match($pubText, '(?ms)^dependencies:\s*(.*?)(?=^dev_dependencies:|^flutter:|^dependency_overrides:|\z)').Groups[1].Value
  # Stop before other top-level YAML keys (flutter_native_splash, flutter_launcher_icons, ...)
  $sectionDev = [regex]::Match($pubText, '(?ms)^dev_dependencies:\s*(.*?)(?=^[a-z_][a-z0-9_]*\s*:|\z)').Groups[1].Value
  $allDepBlocks = $sectionDeps + "`n" + $sectionDev
  foreach ($pm in [regex]::Matches($allDepBlocks, '(?m)^  ([a-z][a-z0-9_]*)\s*:')) {
    $name = $pm.Groups[1].Value
    if (($name -eq 'flutter') -or ($name -eq 'sdk')) {
      continue
    }
    if ($AllowedDirectDeps -notcontains $name) {
      Add-Warn ("Package hors liste stack de base : '{0}' - ADR requis (PACKAGE_POLICY) si ajoute en modernisation ; legacy tolere" -f $name)
    }
  }
}
catch {
  Add-Warn ("Impossible de parser pubspec.yaml : {0}" -f $_)
}

Write-Host ""
Write-Host "--- Resultat heuristiques ---" -ForegroundColor Cyan

if ($script:Warns.Count -gt 0) {
  Write-Host ("WARNINGS ({0}) :" -f $script:Warns.Count) -ForegroundColor Yellow
  foreach ($w in $script:Warns) {
    Write-Host ("  - {0}" -f $w)
  }
}

if ($script:Fails.Count -gt 0) {
  Write-Host ("FAILS ({0}) :" -f $script:Fails.Count) -ForegroundColor Red
  foreach ($f in $script:Fails) {
    Write-Host ("  - {0}" -f $f)
  }
  Write-Host ""
  Write-Host "Verdict script : FAIL - corriger puis rejouer ; review humaine obligatoire." -ForegroundColor Red
  exit 1
}

Write-Host "Aucun FAIL heuristique." -ForegroundColor Green
if ($script:Warns.Count -gt 0) {
  Write-Host "Des warnings restent a trancher dans ARCHITECTURE_REVIEW.md (ex. setState, packages legacy)." -ForegroundColor Yellow
}
Write-Host "Verdict script : PASS heuristique - la review humaine / architecte reste obligatoire." -ForegroundColor Green
exit 0
