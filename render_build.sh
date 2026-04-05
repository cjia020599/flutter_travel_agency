#!/usr/bin/env bash
set -o errexit

# 1. Clone Flutter stable
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Force Flutter to initialize and enable web
# This is the missing piece that makes --web-renderer valid
flutter config --enable-web
flutter doctor -v

# 4. Get dependencies
flutter pub get

# 5. Build the web app
# I've removed the extra '-' in your screenshot it looked like --web-renderer
# but the command below is the standard format.
flutter build web --release --web-renderer canvaskit