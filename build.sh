#!/usr/bin/env bash
set -e
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.38.7 "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
flutter config --no-cli-animations
flutter pub get
flutter build web --release \
  --dart-define=AUTO_EMAIL="$AUTO_EMAIL" \
  --dart-define=AUTO_PASSWORD="$AUTO_PASSWORD"
