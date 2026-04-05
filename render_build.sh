#!/usr/bin/env bash
# Exit on error
set -o errexit

# 1. Download Flutter stable
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Add Flutter to the PATH
export PATH="$PWD/flutter/bin:$PATH"

# 3. Initialize Flutter for Web (IMPORTANT: This prevents Status 64)
flutter config --enable-web --no-analytics
flutter precache --web

# 4. Resolve dependencies
# We run 'pub get' after 'precache' to make sure the packages see the web SDK
flutter pub get

# 5. Build the Web App
# We use 'canvaskit' for your Map features
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://unpkg.com/canvaskit-wasm@0.37.1/bin/