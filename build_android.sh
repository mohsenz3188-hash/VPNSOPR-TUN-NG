#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d android ]; then
  flutter create --platforms=android --org com.vpnsopr --project-name vpnsopr --no-pub .
fi

python3 scripts/patch_android.py
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release --split-per-abi

echo "APK files are in build/app/outputs/flutter-apk/"
