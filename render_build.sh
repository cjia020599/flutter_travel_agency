#!/usr/bin/env bash
set -o errexit

# 1. Force Linux line endings (This fixes the hidden \r character)
# This is likely why --web-renderer keeps failing
sed -i 's/\r$//' render_build.sh

# 2. Fresh Flutter Clone
rm -rf flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"

# 3. Setup
flutter config --no-analytics
flutter config --enable-web
flutter precache --web

# 4. Build
# Try building WITHOUT the renderer flag first to see if it passes
# If this works, then we can add the flag back
flutter build web --release