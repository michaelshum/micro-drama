# iOS App

SwiftUI iOS app for Onda.

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
- rewarded-ad episode unlock flow

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
    Home/
    Onboarding/
    Player/
    Profile/
  Resources/
```

The app consumes `GET /feed` and show detail endpoints for metadata. Each episode includes `playbackPath`; the player calls that endpoint when playback starts and uses the returned signed HLS URL with `AVPlayer`.

Demo API base URL:

```text
https://micro-drama.onrender.com
```

## Local API development

Run the local API from the repository root:

```bash
cd api
npm run dev:local
```

This starts the API on:

```text
http://127.0.0.1:3027
```

For local testing that needs signed Cloudflare Stream thumbnails or playback tickets, copy `api/.env.local.example` to `api/.env.local`, fill in either the Stream signing key values or the Cloudflare API token values, then run:

```bash
cd api
npm run dev:local:env
```

Environment values:

- `CLOUDFLARE_STREAM_SIGNING_KEY_ID`
- `CLOUDFLARE_STREAM_SIGNING_PRIVATE_KEY`
- or `CLOUDFLARE_ACCOUNT_ID` plus `CLOUDFLARE_STREAM_API_TOKEN`
- optional `PLAYBACK_TOKEN_TTL_SECONDS`
- optional `IMAGE_TOKEN_TTL_SECONDS`

The iOS app reads `MicroDramaAPIBaseURL` from `Info.plist`. The Xcode project sets:

- Debug on iOS Simulator: `http://127.0.0.1:3027`
- Debug on a physical iPhone: `https://micro-drama.onrender.com`
- Release: `https://micro-drama.onrender.com`

Run the app with the Debug configuration in the simulator when testing against your local API. Debug builds on a physical phone and Archive/TestFlight builds stay pointed at production. To test a local API from a physical phone, temporarily override `MICRODRAMA_API_BASE_URL` with your Mac's LAN address instead of `127.0.0.1`.
