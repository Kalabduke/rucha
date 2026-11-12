# Building RUCHA for iOS

Since iOS apps can only be built on macOS with Xcode, follow these steps on a Mac:

## Prerequisites

1. **macOS** with Xcode 14.0 or later
2. **Flutter SDK** installed
3. **CocoaPods** installed: `sudo gem install cocoapods`
4. **Apple Developer Account** (free or paid)

## Build Steps

### 1. Install Dependencies

```bash
cd mobile
flutter pub get
cd ios
pod install
cd ..
```

### 2. Configure Code Signing

Open the project in Xcode:

```bash
open ios/Runner.xcworkspace
```

In Xcode:
- Select **Runner** in the project navigator
- Go to **Signing & Capabilities** tab
- Select your **Team** (Apple Developer Account)
- Xcode will automatically create a provisioning profile

### 3. Build Release IPA

#### Option A: Build from Command Line

```bash
# Build archive
flutter build ipa

# The IPA will be in: build/ios/ipa/RUCHA.ipa
```

#### Option B: Build from Xcode

1. In Xcode, select **Product > Archive**
2. Wait for the archive to complete
3. The **Organizer** window opens
4. Select the archive and click **Distribute App**
5. Choose distribution method:
   - **Ad Hoc** - for testing on specific devices
   - **App Store Connect** - for TestFlight/App Store
   - **Development** - for your own devices

### 4. Install on Device

#### Via Xcode (easiest for testing):

```bash
flutter run --release
```

Make sure your iPhone is connected via USB and "Trust This Computer" is confirmed.

#### Via TestFlight (best for distribution):

1. Build and distribute to App Store Connect (Option B above)
2. Upload to TestFlight
3. Share the TestFlight link with testers

## App Configuration

Already configured in `ios/Runner/Info.plist`:

- **Location permissions** - "When In Use" and "Always" (for background tracking)
- **Background modes** - location tracking while locked
- **Bluetooth permissions** - for heart rate monitors
- **Bundle ID**: `com.rucha.mobile`
- **Display name**: `RUCHA`

## Troubleshooting

### CocoaPods Issues

```bash
cd ios
pod repo update
pod deintegrate
pod install
cd ..
```

### Code Signing Errors

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to Signing & Capabilities
4. Enable "Automatically manage signing"
5. Select your team

### Build Errors

```bash
# Clean build
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter pub get
flutter build ios
```

## Release Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Test on real iOS device
- [ ] Test GPS tracking
- [ ] Test background location updates
- [ ] Test map tile loading
- [ ] Verify API connection to production backend
- [ ] Build archive in Release mode
- [ ] Upload to TestFlight for beta testing
- [ ] Submit to App Store Review

## App Store Submission

Required assets:
- App icon (1024x1024px)
- Screenshots (6.7", 6.5", 5.5" required)
- App description
- Privacy policy URL
- Support URL

The app uses:
- Location services (for GPS tracking)
- Background location (for recording while locked)
- Network (for syncing to backend)
- Storage (for caching map tiles and activities)
