import { openAsBlob } from "node:fs";
import { readFile } from "node:fs/promises";
import { basename } from "node:path";

await loadDotEnvLocal();

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = normalizeBearerToken(process.env.CLOUDFLARE_STREAM_API_TOKEN);
const args = parseArgs(process.argv.slice(2));

if (!accountId || !apiToken) {
  console.error("Missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_STREAM_API_TOKEN.");
  process.exit(1);
}

if (args.files.length === 0) {
  console.error("Usage: node scripts/upload-cloudflare-stream-videos.js --name-prefix demo-candy-love-island file.mp4 [...]");
  process.exit(1);
}

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

function parseArgs(rawArgs) {
  const parsed = {
    namePrefix: "",
    replace: true,
    requireSignedURLs: true,
    files: []
  };

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];

    if (arg === "--name-prefix") {
      parsed.namePrefix = rawArgs[++index] || "";
    } else if (arg === "--keep-existing") {
      parsed.replace = false;
    } else if (arg === "--public") {
      parsed.requireSignedURLs = false;
    } else {
      parsed.files.push(arg);
    }
  }

  return parsed;
}

function episodeNumberFromFile(path) {
  const match = basename(path).match(/s\d{2}-?e(?<episode>\d{2})/i);
  if (!match?.groups?.episode) {
    throw new Error(`Could not infer episode number from ${path}`);
  }

  return Number(match.groups.episode);
}

function streamNameForFile(path) {
  const episodeNumber = episodeNumberFromFile(path);
  const episode = String(episodeNumber).padStart(2, "0");

  if (args.namePrefix) {
    return `${args.namePrefix}-s01e${episode}`;
  }

  return basename(path, ".mp4").replace(/-s01-?e/i, "-s01e");
}

async function cloudflareRequest(path, options = {}) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}${path}`,
    {
      ...options,
      headers: {
        Authorization: `Bearer ${apiToken}`,
        ...(options.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
        ...options.headers
      }
    }
  );
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};

  if (!response.ok || payload.success === false) {
    throw new Error(`Cloudflare ${options.method || "GET"} ${path} failed with ${response.status}: ${text}`);
  }

  return payload;
}

async function fetchVideos() {
  const videos = [];
  let page = 1;

  while (true) {
    const path = `/stream?per_page=100&page=${page}`;
    const payload = await cloudflareRequest(path);
    videos.push(...(payload.result || []));

    const resultInfo = payload.result_info;
    if (!resultInfo || page >= resultInfo.total_pages) {
      break;
    }

    page += 1;
  }

  return videos;
}

async function deleteVideosWithName(name) {
  const videos = await fetchVideos();
  const matchingVideos = videos.filter((video) => video.meta?.name === name);

  for (const video of matchingVideos) {
    await cloudflareRequest(`/stream/${video.uid}`, { method: "DELETE" });
    console.error(`Deleted existing ${name} (${video.uid})`);
  }
}

async function uploadVideo(filePath, name) {
  const form = new FormData();
  const blob = await openAsBlob(filePath, { type: "video/mp4" });
  form.set("file", blob, basename(filePath));
  form.set("meta", JSON.stringify({ name }));

  const payload = await cloudflareRequest("/stream", {
    method: "POST",
    body: form
  });

  const video = payload.result;
  await cloudflareRequest(`/stream/${video.uid}`, {
    method: "POST",
    body: JSON.stringify({
      uid: video.uid,
      requireSignedURLs: args.requireSignedURLs,
      meta: { name }
    })
  });

  return {
    name,
    filePath,
    episodeNumber: episodeNumberFromFile(filePath),
    cloudflareVideoUid: video.uid,
    status: video.readyToStream ? "ready" : "processing",
    durationSeconds: Math.round(Number(video.duration || 0)),
    playbackUrl: `https://videodelivery.net/${video.uid}/manifest/video.m3u8`,
    thumbnailUrl: `https://videodelivery.net/${video.uid}/thumbnails/thumbnail.jpg`
  };
}

const rows = [];

for (const filePath of args.files) {
  const name = streamNameForFile(filePath);

  if (args.replace) {
    await deleteVideosWithName(name);
  }

  console.error(`Uploading ${filePath} as ${name}`);
  rows.push(await uploadVideo(filePath, name));
}

console.log(JSON.stringify(rows, null, 2));
