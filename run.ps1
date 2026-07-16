# Convenience launcher for the Shop Manager app.
# 1) Install Flutter (see README).  2) Copy dart_defines.example.json to
#    dart_defines.json and fill in your keys.  3) Run:  ./run.ps1
$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter is not installed or not on PATH." -ForegroundColor Red
  Write-Host "Install it from https://docs.flutter.dev/get-started/install/windows"
  exit 1
}

if (-not (Test-Path "dart_defines.json")) {
  Write-Host "dart_defines.json not found. Copy the example and add your keys:" -ForegroundColor Yellow
  Write-Host "  Copy-Item dart_defines.example.json dart_defines.json"
  exit 1
}

if (-not (Test-Path "android") -and -not (Test-Path "ios") -and -not (Test-Path "windows")) {
  Write-Host "Generating platform folders (flutter create .)..." -ForegroundColor Cyan
  flutter create .
}

flutter pub get
flutter run --dart-define-from-file=dart_defines.json
