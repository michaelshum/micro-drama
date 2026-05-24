# iOS App

SwiftUI iOS app for the Micro Drama demo.

Open `MicroDrama.xcodeproj` in Xcode and run the `MicroDrama` scheme.

Command-line simulator build:

```bash
xcodebuild -project MicroDrama.xcodeproj -scheme MicroDrama -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/MicroDramaDerivedData build
```

Planned MVP scope:

- full-screen vertical episode player
- feed backed by the Render API
- show detail view
- local watch progress
- local bookmarks
- mock locked episode/paywall flow

Suggested app structure once the Xcode project is created:

```text
MicroDrama/
  App/
  Core/
    API/
    Models/
    Playback/
    Storage/
  Features/
    Feed/
    Player/
    Shows/
    Paywall/
  Resources/
```

For the first implementation, the app should consume `GET /feed` and treat each episode's `playbackUrl` as an HLS URL playable by `AVPlayer`.

Demo API base URL:

```text
https://micro-drama.onrender.com
```
