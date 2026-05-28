import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(__dirname, "..", "data", "catalog.json");

await loadDotEnvLocal();

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = normalizeBearerToken(process.env.CLOUDFLARE_STREAM_API_TOKEN);

async function loadDotEnvLocal() {
  const candidates = [".env.local", "../.env.local"];

  for (const path of candidates) {
    try {
      const raw = await readFile(path, "utf8");

      for (const line of raw.split(/\r?\n/)) {
        const trimmed = line.trim();

        if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) {
          continue;
        }

        const index = trimmed.indexOf("=");
        const key = trimmed.slice(0, index).trim();
        const value = trimmed.slice(index + 1).trim().replace(/^['"]|['"]$/g, "");

        if (key && process.env[key] === undefined) {
          process.env[key] = value;
        }
      }

      return;
    } catch (error) {
      if (error.code !== "ENOENT") {
        throw error;
      }
    }
  }
}

function normalizeBearerToken(value) {
  return value?.trim().replace(/^Bearer\s+/i, "");
}

if (!accountId || !apiToken) {
  console.error("Missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_STREAM_API_TOKEN.");
  process.exit(1);
}

async function verifyApiToken() {
  const response = await fetch("https://api.cloudflare.com/client/v4/user/tokens/verify", {
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json"
    }
  });

  const body = await response.text();
  if (!response.ok) {
    throw new Error(
      `Cloudflare API token verification failed with ${response.status}: ${body}\n` +
        "Check that CLOUDFLARE_STREAM_API_TOKEN is the token value, not the token name or ID, and that it has not been revoked or expired."
    );
  }
}

await verifyApiToken();

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
