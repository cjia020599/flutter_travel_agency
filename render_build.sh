#!/usr/bin/env bash
set -o errexit

# 1. Clone Flutter
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Setup Environment
flutter config --no-analytics
flutter config --enable-web
flutter precache --web

# 4. Refresh Dependencies
# This clears out any conflicting lock files from local builds
rm -f pubspec.lock
flutter pub get

# 5. The Build (The Fix is here)
# We add --no-wasm to stop the 'wasm dry run' crash
flutter build web --release