#!/usr/bin/env bash
set -o errexit

# 1. Update Flutter if it exists, otherwise clone it
if [ -d "flutter" ]; then
  echo "Old Flutter found. Updating to the latest stable..."
  cd flutter
  git fetch --all
  git checkout stable
  git reset --hard origin/stable
  cd ..
else
  echo "Cloning fresh Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Setup
flutter config --no-analytics
flutter config --enable-web

# 4. Deep Clean (Crucial for moving past the version error)
# This forces the project to re-check the SDK requirements
flutter clean
rm -f pubspec.lock
flutter pub get

# 5. Build
# We skip the --no-wasm flag since it was causing issues
# and let the latest stable handle the renderer.
flutter build web --release --web-renderer canvaskit