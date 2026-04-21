#!/bin/bash
# Setup script for the Conferbot Flutter example app.
# Generates platform directories (android/, ios/, etc.) and fetches dependencies.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Generating platform directories with flutter create..."
flutter create --org com.conferbot .

echo ""
echo "Fetching dependencies..."
flutter pub get

echo ""
echo "Setup complete! You can now run the example app:"
echo "  flutter run"
