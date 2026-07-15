$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dest = "build\app\outputs\flutter-apk\Sacostay.apk"

if (-not (Test-Path $src)) {
    Write-Error "Khong tim thay file build: $src"
}

Copy-Item -Path $src -Destination $dest -Force
Write-Host ""
Write-Host "APK: $dest" -ForegroundColor Green
