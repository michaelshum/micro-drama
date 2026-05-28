import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(__dirname, "..", "data", "catalog.json");

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = process.env.CLOUDFLARE_STREAM_API_TOKEN;

if (!accountId || !apiToken) {
  console.error("Missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_STREAM_API_TOKEN.");
  process.exit(1);
}

const catalog = JSON.parse(await readFile(catalogPath, "utf8"));
const videoUids = [
  ...new Set(
    catalog.episodes
      .filter((episode) => episode.provider === "cloudflare_stream" && episode.providerAssetId)
      .map((episode) => episode.providerAssetId)
  )
];

for (const videoUid of videoUids) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${videoUid}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        uid: videoUid,
        requireSignedURLs: true
      })
    }
  );

  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Failed to secure ${videoUid}: ${response.status} ${body}`);
  }

  console.log(`requireSignedURLs enabled for ${videoUid}`);
}

