# Découpe Dart en fichiers `part` — exécuter UNE section à la fois.
# Ne pas relancer les splits déjà appliqués (risque de tronquer les fichiers).
#
# Usage: décommenter la section voulue puis:
#   powershell -ExecutionPolicy Bypass -File tools/split_dart_parts.ps1

function Split-DartLibrary {
  param(
    [Parameter(Mandatory)][string]$MainPath,
    [Parameter(Mandatory)][array]$Segments,
    [string]$PartOfParent = ''
  )

  $MainPath = (Resolve-Path $MainPath).Path
  $dir = Split-Path $MainPath
  $mainName = Split-Path $MainPath -Leaf
  $all = Get-Content $MainPath -Encoding UTF8

  $parentFromFile = ''
  if ($all.Count -gt 0 -and $all[0] -match "^part of '(.+)';") {
    $parentFromFile = $Matches[1]
    $isPartFile = $true
  } else {
    $isPartFile = $false
  }
  $libraryName = if ($PartOfParent) { $PartOfParent } elseif ($parentFromFile) { $parentFromFile } else { $mainName }
  $partOfHeader = "part of '$libraryName';`n`n"
  $bodyStart = 0
  $headerLines = @()

  if (-not $isPartFile) {
    $i = 0
    while ($i -lt $all.Count) {
      $trim = $all[$i].TrimStart()
      if ($trim.StartsWith('import ') -or $trim.StartsWith('export ') -or $trim -eq '' -or $trim.StartsWith('part ') -or $trim.StartsWith('//')) {
        $headerLines += $all[$i]
        $i++
      } else {
        break
      }
    }
    $bodyStart = $i
  }

  $splitPoints = @($Segments | ForEach-Object { [int]$_.Start } | Sort-Object)
  $partNames = @($Segments | ForEach-Object { $_.Name })

  for ($p = 0; $p -lt $splitPoints.Count; $p++) {
    $start = $splitPoints[$p] - 1  # convert to 0-based
    $end = if ($p + 1 -lt $splitPoints.Count) { $splitPoints[$p + 1] - 2 } else { $all.Count - 1 }
    if ($start -gt $end) { continue }
    $chunk = $all[$start..$end]
    if ($chunk.Count -gt 0 -and $chunk[0] -match '^part of ') {
      $chunk = $chunk[1..($chunk.Count - 1)]
    }
    $content = $partOfHeader + ($chunk -join "`n") + "`n"
    Set-Content -Path (Join-Path $dir $partNames[$p]) -Value $content -Encoding UTF8
    Write-Host "  + $($partNames[$p]) ($($chunk.Count) lines)"
  }

  $mainEnd = $splitPoints[0] - 2
  if ($mainEnd -lt $bodyStart) { $mainEnd = $bodyStart - 1 }

  if ($isPartFile) {
    if ($mainEnd -lt 0) { $mainEnd = 0 }
    $newLines = $all[0..$mainEnd]
    Set-Content -Path $MainPath -Value (($newLines -join "`n") + "`n") -Encoding UTF8
  } else {
    $partDirectives = @($partNames | ForEach-Object { "part '$_';" })
    $mainChunk = if ($mainEnd -ge $bodyStart) { $all[$bodyStart..$mainEnd] } else { @() }
    $newMain = $headerLines + $partDirectives + @('') + $mainChunk
    Set-Content -Path $MainPath -Value (($newMain -join "`n") + "`n") -Encoding UTF8
  }

  Write-Host "  main $mainName -> $($mainEnd - $bodyStart + 1) body lines"
}

function Add-PartsToParent {
  param(
    [string]$ParentPath,
    [string[]]$PartNames
  )
  $all = Get-Content $ParentPath -Encoding UTF8
  $out = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $all) { [void]$out.Add($line) }
  $insertAt = 0
  for ($i = 0; $i -lt $out.Count; $i++) {
    if ($out[$i] -match "^part '") { $insertAt = $i + 1 }
  }
  foreach ($p in $PartNames) {
    $directive = "part '$p';"
    if ($out -notcontains $directive) {
      $out.Insert($insertAt, $directive)
      $insertAt++
    }
  }
  Set-Content -Path $ParentPath -Value (($out -join "`n") + "`n") -Encoding UTF8
}

$root = "C:\Users\axeld\Music\dvcr_appli"

Write-Host "No split configured — uncomment a block below to run one split."
Write-Host "Done."
