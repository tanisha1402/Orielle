# Generates the Android + Web platform folders (not shipped in the ZIP) and
# adds the INTERNET permission needed for map tiles in Android release builds.
# Safe to re-run: `flutter create` does not overwrite existing files.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter was not found on PATH. Install it first: https://docs.flutter.dev/get-started/install'
}

flutter create . --platforms=android,web --project-name earth_risk_chain

$manifest = 'android/app/src/main/AndroidManifest.xml'
if ((Test-Path $manifest) -and -not (Select-String -Path $manifest -Pattern 'android.permission.INTERNET' -Quiet)) {
  $lines = Get-Content $manifest
  $out = foreach ($line in $lines) {
    $line
    if ($line -match '<manifest ') { '    <uses-permission android:name="android.permission.INTERNET"/>' }
  }
  Set-Content -Path $manifest -Value $out
  Write-Host "Added INTERNET permission to $manifest"
}

flutter pub get
Write-Host 'Done. Next: flutter analyze; flutter test; flutter run'
