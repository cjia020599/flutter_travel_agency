#!/usr/bin/env bash
# Exit on error
set -o errexit

# 1. Download Flutter (if not present)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Set the Path
export PATH="$PWD/flutter/bin:$PATH"

# 3. Upgrade/Verify Flutter 
# This ensures the tool is downloaded and ready
flutter doctor -v

# 4. Get dependencies 
# This is usually why builds fail (missing packages like flutter_map)
flutter pub get

# 5. Build the web app
# Added --web-renderer canvaskit as maps often need better performance
flutter build web --release --web-renderer canvaskit