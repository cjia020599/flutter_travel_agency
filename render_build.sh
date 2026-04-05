#!/usr/bin/env bash
set -o errexit

# 1. Clone Flutter if it doesn't exist
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# 3. Pre-cache artifacts (Crucial for CI/CD like Render)
flutter config --no-analytics
flutter precache --web

# 4. Clean and Get Dependencies
# This fixes many "Status 64" errors caused by stale build caches
flutter clean
flutter pub get

# 5. Build for Web
# We use --web-renderer canvaskit because it's more stable for Map packages
flutter build web --release --web-renderer canvaskit