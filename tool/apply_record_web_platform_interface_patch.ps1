# Aligns record_web 1.1.9 with record_platform_interface 1.6+ (hasPermission request param).
$ErrorActionPreference = "Stop"
$version = "1.1.9"
$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$pluginDir = Join-Path $pubCache "record_web-$version"
$patchDir = Join-Path $PSScriptRoot "patches\record_web-$version"
if (-not (Test-Path $pluginDir)) {
  Write-Error "record_web not found in pub cache. Run 'flutter pub get' first."
}
Copy-Item (Join-Path $patchDir "lib\record_web.dart") (Join-Path $pluginDir "lib\record_web.dart") -Force
Copy-Item (Join-Path $patchDir "lib\recorder\recorder.dart") (Join-Path $pluginDir "lib\recorder\recorder.dart") -Force
Write-Host "Applied record_web platform interface patch to $pluginDir"
