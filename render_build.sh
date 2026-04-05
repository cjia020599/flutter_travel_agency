#!/usr/bin/env bash
set -o errexit

# 1. Clone a SPECIFIC stable version to avoid the WASM bug
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b 3.22.2
fi

# 2. Add to PATH
export PATH="$PWD/flutter/bin:$PATH"

# 3. Setup
flutter config --no-analytics
flutter config --enable-web
flutter precache --web

# 4. Clean and Resolve
rm -rf .dart_tool
rm -f pubspec.lock
flutter pub get

# 5. Build
# This version doesn't have the "Negate no-wasm" error or the dry-run crash
flutter build web --release --web-renderer canvaskit