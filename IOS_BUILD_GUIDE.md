# RUCHA iOS Build Guide

## ⚠️ Important: macOS Required

iOS apps can **only be built on macOS** with Xcode installed. This guide is for when you have access to a Mac.

## What's Already Configured

✅ **Info.plist** - All permissions configured:
- Location "When In Use" permission
- Location "Always" permission (for background tracking)
- Background location mode
- Bluetooth permission (for heart rate monitors)

✅ **Bundle ID**: `com.rucha.mobile`

✅ **Display Name**: `RUCHA`

✅ **Podfile** - CocoaPods configuration ready

✅ **All Flutter dependencies** in `pubspec.yaml`

---

## Quick Start (on macOS)

### 1. Prerequisites

```bash
# Install CocoaPods (if not already installed)
sudo gem install cocoapods

# Verify Flutter
flutter doctor
```

### 2. Build iOS App

```bash
cd mobile

# Option A: Use the build script
./scripts/build_ios.sh

# Option B: Manual build
flutter pub get
cd ios && pod install && cd ..
flutter build ipa
```

The IPA will be created at: `build/ios/ipa/RUCHA.ipa`

### 3. Test on Device

```bash
# Connect iPhone via USB
# Make sure device is unlocked and "Trust This Computer" is confirmed

flutter run --release
```

---

## Detailed Build Process

### Step 1: Install Dependencies

```bash
cd mobile
flutter pub get
```

This installs all Flutter packages from `pubspec.yaml`.

### Step 2: Install iOS Native Dependencies

```bash
cd ios
pod install
cd ..
```

This installs native iOS libraries (geolocator, bluetooth, etc.) via CocoaPods.

### Step 3: Configure Code Signing

**You need an Apple Developer Account** (free or $99/year paid).

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select **Runner** in left sidebar
   - Click **Signing & Capabilities** tab
   - Under **Signing**, select your **Team**
   - Xcode auto-generates a provisioning profile

**Bundle ID**: `com.rucha.mobile`
- Free accounts can only use: `com.yourname.rucha` or similar
- Change in Xcode if needed

### Step 4: Build Release IPA

```bash
flutter build ipa
```

Output: `build/ios/ipa/RUCHA.ipa`

---

## Distribution Methods

### Option 1: Ad Hoc (Physical Devices)

For testing on specific iPhones/iPads.

1. Build archive in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Product > Archive
   - Organizer opens > Distribute App
   - Choose **Ad Hoc**

2. Register device UDIDs in Apple Developer portal
3. Install via Xcode or Apple Configurator

### Option 2: TestFlight (Beta Testing)

Best for distributing to testers before App Store.

1. Build archive:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Product > Archive
   - Organizer > Distribute App
   - Choose **App Store Connect**

2. Upload to App Store Connect
3. In App Store Connect:
   - Go to TestFlight tab
   - Add external testers
   - Share TestFlight link

Testers install via TestFlight app.

### Option 3: App Store (Public Release)

1. Follow TestFlight steps above
2. In App Store Connect:
   - Submit for review
   - Fill out app metadata:
     - Screenshots
     - Description
     - Privacy policy
     - Support URL

---

## Troubleshooting

### "No Podfile found"

```bash
cd mobile/ios
# Copy the Podfile we created
pod install
```

### "Code signing failed"

1. Open `ios/Runner.xcworkspace` (NOT .xcodeproj!)
2. Select Runner target
3. Signing & Capabilities
4. Enable "Automatically manage signing"
5. Select your team

### "Build failed" or dependency errors

```bash
cd mobile

# Nuclear option - clean everything
flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf build/

# Rebuild from scratch
flutter pub get
cd ios
pod repo update
pod install
cd ..
flutter build ipa
```

### "Module not found" errors

This usually means CocoaPods didn't install correctly:

```bash
cd mobile/ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter build ipa
```

---

## App Capabilities

The app uses these iOS features (already configured):

| Capability | Purpose | Background? |
|------------|---------|-------------|
| Location Services | Track GPS route | ✅ Yes |
| Background Location | Record while locked | ✅ Yes |
| Bluetooth LE | Heart rate monitors | ❌ No |
| Network | Sync to backend API | ❌ No |
| Storage | Cache map tiles | ❌ No |

---

## Testing Checklist

Before distributing:

- [ ] Test on real iPhone (not just simulator)
- [ ] Start recording on Record tab
- [ ] Lock phone - recording continues
- [ ] Unlock - map updates with new route
- [ ] Save activity - appears on History tab
- [ ] View activity detail - map and stats render
- [ ] Explore tab - see popular areas
- [ ] Community tab - see all activities
- [ ] Account tab - login/signup works

---

## App Store Submission Requirements

### Required Assets

1. **App Icon**: 1024×1024 px (no transparency, no rounded corners)
2. **Screenshots**:
   - iPhone 6.7" (e.g., iPhone 15 Pro Max): at least 1
   - iPhone 6.5" (e.g., iPhone 11 Pro Max): at least 1
   - iPhone 5.5" (e.g., iPhone 8 Plus): optional
3. **Privacy Policy URL** (required for apps using location)
4. **Support URL**

### App Metadata

- **Category**: Health & Fitness
- **Age Rating**: 4+ (no mature content)
- **Description**: Highlight altitude-aware GPS tracking
- **Keywords**: running, cycling, GPS, tracker, fitness, Ethiopia

### Privacy Declaration

You must declare:
- ✅ Location data collected
- ✅ Used for app functionality (tracking)
- ❌ Not shared with third parties
- ❌ Not used for advertising

### Review Notes

Tell Apple reviewers:
> "RUCHA is a GPS fitness tracker. To test recording:
> 1. Allow location permissions when prompted
> 2. Tap Record tab
> 3. Tap Start
> 4. Walk/run for 30 seconds
> 5. Tap Finish
> 
> The app tracks in background when device is locked."

---

## Version Bumping

Before each release, update version:

```yaml
# mobile/pubspec.yaml
version: 1.0.1+2  # 1.0.1 = user-facing, +2 = build number
```

Then rebuild:
```bash
flutter build ipa
```

---

## Current Status

✅ **App fully configured** for iOS
✅ **All permissions** set in Info.plist
✅ **Background tracking** enabled
✅ **Podfile** ready for CocoaPods
✅ **Bundle ID**: com.rucha.mobile
✅ **Build script** at `scripts/build_ios.sh`

**Next step**: Run on macOS with Xcode installed.

---

## Links

- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos/mobile-ios)
- [App Store Connect](https://appstoreconnect.apple.com)
- [TestFlight](https://developer.apple.com/testflight/)
- [Apple Developer](https://developer.apple.com)
