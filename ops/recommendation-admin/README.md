# Recommendation Admin

Local-only operations UI for assigning show-level recommendation metadata.

```bash
cd api
npm run recommendation:admin
```

Then open:

```text
http://localhost:3015
```

The admin reads and writes `api/data/catalog.json`. Each show's recommendation metadata is stored in `show.recommendation` so the future recommendation scorer can use the same source of truth as the public catalog API.

Reusable field suggestions are stored in `api/data/recommendation-options.json`. Token fields can accept new values that are not already in the option bank; when a show is saved, those values are added to that field's suggestions. The Option Bank panel can also add or remove suggestions directly.

Manual show quality ratings use a 1-5 scale where higher numbers are better.

Episode playback uses the same Cloudflare Stream signing credentials as the API. Add these to `.env.local` at the repo root or `api/.env.local`:

```bash
CLOUDFLARE_STREAM_SIGNING_KEY_ID=...
CLOUDFLARE_STREAM_SIGNING_PRIVATE_KEY=...
```

If local signing is not available, the admin can also request Stream tokens with:

```bash
CLOUDFLARE_ACCOUNT_ID=...
CLOUDFLARE_STREAM_API_TOKEN=...
```

This tool is intentionally separate from the production API. Do not expose it on Render without adding authentication and write protections.
