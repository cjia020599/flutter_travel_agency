#!/usr/bin/env bash
set -o errexit

# 1. Start fresh - delete old flutter folder if it exists
rm -rf flutter

# 2. Clone fresh stable (shallow clone for speed)
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 3. Set the Path
export PATH="$PWD/flutter/bin:$PATH"

# 4. UNLOCK WEB FEATURES (This stops Status 64)
# We must do these in this EXACT order
flutter config --enable-web
flutter precache --web

# 5. Get dependencies for your Travel Agency app
# We'll remove the lock file to avoid Windows vs Linux conflicts
rm -f pubspec.lock
flutter pub get

# 6. The Build
# If this still gives Error 64, remove "--web-renderer canvaskit"
# and just use "flutter build web --release" to get it live first.
flutter build web --release --web-renderer canvaskit