# Applies Android Gradle/Java fixes for flutter_webrtc 0.11.6+hotfix.1 (Gradle 8 + Flutter 3.38).
$ErrorActionPreference = "Stop"
$version = "0.11.6+hotfix.1"
$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$pluginDir = Join-Path $pubCache "flutter_webrtc-$version\android"
$patchDir = Join-Path $PSScriptRoot "patches\flutter_webrtc-$version\android"
if (-not (Test-Path $pluginDir)) {
  Write-Error "flutter_webrtc not found in pub cache. Run 'flutter pub get' first."
}
Copy-Item (Join-Path $patchDir "build.gradle") (Join-Path $pluginDir "build.gradle") -Force
Copy-Item (Join-Path $patchDir "src\main\java\com\cloudwebrtc\webrtc\FlutterWebRTCPlugin.java") (
  Join-Path $pluginDir "src\main\java\com\cloudwebrtc\webrtc\FlutterWebRTCPlugin.java"
) -Force
Write-Host "Applied flutter_webrtc Android patch to $pluginDir"
