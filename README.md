# Micro Drama

Monorepo for the micro-drama product demo.

## Structure

```text
apps/
  ios/       SwiftUI iOS app workspace placeholder
api/         Render metadata API
```

## API

The initial API is a small Render-ready Node service that serves show, episode, feed, and app configuration metadata.

```bash
cd api
npm start
```

The API runs on `http://localhost:3000` by default.

Endpoints:

```text
GET /health
GET /config
GET /feed
GET /feed?feed=featured
GET /shows
GET /shows/:showId
GET /shows/:showId/episodes
GET /episodes/:episodeId
```

## Catalog

Edit `api/data/catalog.json` to update shows, episodes, feed ordering, Cloudflare Stream playback URLs, thumbnails, and lock states.

For Cloudflare Stream, each episode should eventually store:

```json
{
  "provider": "cloudflare_stream",
  "providerAssetId": "cloudflare-video-uid",
  "thumbnailUrl": "https://videodelivery.net/cloudflare-video-uid/thumbnails/thumbnail.jpg",
  "playbackUrl": "https://videodelivery.net/cloudflare-video-uid/manifest/video.m3u8"
}
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
