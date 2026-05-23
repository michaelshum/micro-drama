# iOS App

Placeholder for the SwiftUI iOS app.

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
