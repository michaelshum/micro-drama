import { readFile } from "node:fs/promises";

await loadDotEnvLocal();

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = process.env.CLOUDFLARE_STREAM_API_TOKEN;
const namePrefixes = (process.env.CLOUDFLARE_STREAM_NAME_PREFIX || "")
  .split(",")
  .map((prefix) => prefix.trim())
  .filter(Boolean);

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

if (!accountId || !apiToken) {
  console.error("Missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_STREAM_API_TOKEN.");
  process.exit(1);
}

function parseVideoName(name) {
  const normalized = String(name || "")
    .trim()
    .replace(/\.(mp4|mov|m4v|webm)$/i, "");
  const match = normalized.match(/^(?<showSlug>.+)-s(?<season>\d{2})-?e(?<episode>\d{2})(?:-(?<title>.+))?$/i);

  if (!match?.groups) {
    return {
      name: normalized,
      showSlug: null,
      seasonNumber: null,
      episodeNumber: null,
      episodeTitle: null
    };
  }

  return {
    name: normalized,
    showSlug: match.groups.showSlug.toLowerCase(),
    seasonNumber: Number(match.groups.season),
    episodeNumber: Number(match.groups.episode),
    episodeTitle: match.groups.title ? titleFromSlug(match.groups.title) : null
  };
}

function titleFromSlug(slug) {
  return slug
    .split("-")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

async function fetchVideos() {
  const videos = [];
  let page = 1;

  while (true) {
    const url = new URL(`https://api.cloudflare.com/client/v4/accounts/${accountId}/stream`);
    url.searchParams.set("per_page", "100");
    url.searchParams.set("page", String(page));

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Cloudflare API failed with ${response.status}: ${body}`);
    }

    const payload = await response.json();
    videos.push(...(payload.result || []));

    const resultInfo = payload.result_info;
    if (!resultInfo || page >= resultInfo.total_pages) {
      break;
    }

    page += 1;
  }

  return videos;
}

const videos = await fetchVideos();

const rowsByName = new Map();

for (const video of videos) {
  if (namePrefixes.length > 0) {
    const name = video.meta?.name || "";
    const normalizedName = name.replace(/\.(mp4|mov|m4v|webm)$/i, "");

    if (!namePrefixes.some((prefix) => normalizedName.startsWith(prefix))) {
      continue;
    }
  }

  const name = video.meta?.name || video.uid;
  const parsed = parseVideoName(name);
  const row = {
    ...parsed,
    cloudflareVideoUid: video.uid,
    durationSeconds: Math.round(Number(video.duration || 0)),
    status: video.readyToStream ? "ready" : "processing",
    playbackUrl: `https://videodelivery.net/${video.uid}/manifest/video.m3u8`,
    thumbnailUrl: `https://videodelivery.net/${video.uid}/thumbnails/thumbnail.jpg`,
    createdAt: video.created
  };

  const existing = rowsByName.get(row.name);

  if (
    !existing ||
    (existing.status !== "ready" && row.status === "ready") ||
    (existing.status === row.status && Date.parse(row.createdAt) > Date.parse(existing.createdAt))
  ) {
    rowsByName.set(row.name, row);
  }
}

const rows = Array.from(rowsByName.values())
  .sort((a, b) => {
    if (a.showSlug !== b.showSlug) {
      return String(a.showSlug).localeCompare(String(b.showSlug));
    }

    return Number(a.episodeNumber || 0) - Number(b.episodeNumber || 0);
  });

console.log(JSON.stringify(rows, null, 2));
