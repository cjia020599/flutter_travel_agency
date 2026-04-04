#!/usr/bin/env bash
# Exit on error
set -o errexit

# 1. Download Flutter
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set the Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Build the web app
flutter build web --release --web-renderer canvaskit