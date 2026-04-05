#!/usr/bin/env bash
set -o errexit

# 1. Clone Flutter
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Setup (This fixes the Status 64 errors we had)
flutter config --no-analytics
flutter config --enable-web
flutter precache --web

# 4. CRITICAL: Deep Clean (This fixes the Status 1 errors)
# Removing these forces Render to download Linux-compatible map libraries
rm -rf .dart_tool
rm -f pubspec.lock
flutter pub get

# 5. Build
# We use the basic build command first to ensure it passes
flutter build web --release