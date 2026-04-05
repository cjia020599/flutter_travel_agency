#!/usr/bin/env bash
set -o errexit

# 1. Clone Flutter stable if not already there
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Add to PATH
export PATH="$PWD/flutter/bin:$PATH"

# 3. Initialize the Flutter Tool
# We disable analytics to speed up the build and enable web
flutter config --no-analytics
flutter config --enable-web

# 4. CRITICAL: Pre-download Web artifacts
# This ensures the tool recognizes web-specific flags
flutter precache --web

# 5. Get project dependencies
flutter pub get

# 6. Build for Web
# If this still fails, we can try removing --web-renderer canvaskit 
# and just use 'flutter build web --release' to see if it passes.
flutter build web --release