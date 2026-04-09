#!/bin/bash
# Install Flutter
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add Flutter to the path
export PATH="$PATH:`pwd`/flutter/bin"

# Install dependencies
echo "Installing dependencies..."
flutter pub get

# Build the web app
echo "Building Flutter Web..."
flutter build web --release
