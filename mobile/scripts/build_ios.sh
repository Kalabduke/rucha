#!/bin/bash
# Build RUCHA iOS app
# Must be run on macOS with Xcode installed

set -e

echo "🏃 Building RUCHA iOS app..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: iOS builds require macOS with Xcode"
    echo "📖 See BUILD_IOS.md for instructions"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed"
    echo "📥 Install from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "⚠️  Warning: CocoaPods not found"
    echo "📥 Installing CocoaPods..."
    sudo gem install cocoapods
fi

cd "$(dirname "$0")/.."

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🍎 Installing iOS dependencies..."
cd ios
pod install
cd ..

echo "🔨 Building iOS app..."
flutter build ipa

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "📱 IPA location: build/ios/ipa/RUCHA.ipa"
    echo ""
    echo "Next steps:"
    echo "  • Test on device: flutter run --release"
    echo "  • Upload to TestFlight via Xcode Organizer"
    echo "  • Distribute via App Store Connect"
else
    echo ""
    echo "❌ Build failed"
    echo "📖 See BUILD_IOS.md for troubleshooting"
    exit 1
fi
