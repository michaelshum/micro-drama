# Onda

Monorepo for Onda, a short-drama product demo.

## Structure

```text
apps/
  ios/       SwiftUI iOS app workspace placeholder
api/         Render metadata API
```

## API

The initial API is a small Render-ready Node service that serves show, episode, feed, and app configuration metadata.

Deployed demo API:

```text
https://micro-drama.onrender.com
```

```bash
cd api
npm start
```

The API runs on `http://localhost:3000` by default.

For iOS simulator development against a local API, use the fixed local dev port:

```bash
cd api
npm run dev:local
```

This runs the API on `http://127.0.0.1:3027`, which the iOS Debug build points to through `MICRODRAMA_API_BASE_URL`. Archive/TestFlight builds use the Release configuration and stay pointed at the deployed API.

Endpoints:

```text
GET /health
GET /config
GET /feed
GET /feed?feed=featured
POST /home
GET /shows
GET /shows/:showId
GET /shows/:showId/poster
GET /shows/:showId/cover
GET /shows/:showId/episodes
GET /episodes/:episodeId
GET /episodes/:episodeId/thumbnail
GET /episodes/:episodeId/playback
```

## Catalog

Edit `api/data/catalog.json` to update shows, episodes, feed ordering, Cloudflare Stream asset IDs, thumbnails, and lock states.

For Cloudflare Stream, each episode should store:

```json
{
  "provider": "cloudflare_stream",
  "providerAssetId": "cloudflare-video-uid"
}
```

Public metadata responses do not expose raw Stream manifests. Clients receive `playbackPath` and call that endpoint when playback starts. Thumbnails, posters, and covers are returned as signed Cloudflare image URLs when local signing is configured so image loading can go directly to Cloudflare. The image redirect endpoints remain available as a fallback.

Uploaded Cloudflare Stream videos should use this name pattern:

```text
demo-candy-love-island-s01e01
demo-candy-love-island-s01e02
demo-candy-love-island-s01e03
```

To list Cloudflare Stream videos and derive app-ready URLs:

```bash
cd api
npm run cloudflare:videos
```

Optional local config in `.env.local` at the repo root or in `api/.env.local`:

```bash
CLOUDFLARE_ACCOUNT_ID=...
CLOUDFLARE_STREAM_API_TOKEN=...
CLOUDFLARE_STREAM_SIGNING_KEY_ID=...
CLOUDFLARE_STREAM_SIGNING_PRIVATE_KEY=...
PLAYBACK_TOKEN_TTL_SECONDS=1800
IMAGE_TOKEN_TTL_SECONDS=86400
CLOUDFLARE_STREAM_NAME_PREFIX=demo-fruit-love-island,demo-candy-love-island
```

The script prints JSON with `showSlug`, `episodeNumber`, `cloudflareVideoUid`, `durationSeconds`, `playbackUrl`, and `thumbnailUrl`.

For production, enable `requireSignedURLs` for all catalog videos in Cloudflare Stream:

```bash
cd api
npm run cloudflare:require-signed
```

## Render

The API includes `api/render.yaml`. Create a new Blueprint on Render from this repository, or create a Web Service manually with the root directory set to `api`:

```text
Build command: npm install
Start command: npm start
Health check path: /health
```

## Demo Content Guidance

Start with 2-3 shows and 2-3 episodes each. That is enough to demo browsing, vertical playback, episode progression, and a locked episode/paywall moment. Ten shows is only useful if the clips are polished and distinct; otherwise it makes the demo feel sparse.
