import { createServer } from "node:http";
import { createPrivateKey, createSign } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(__dirname, "..", "data", "catalog.json");
const port = Number(process.env.PORT || 3000);
const playbackTokenTtlSeconds = Number(process.env.PLAYBACK_TOKEN_TTL_SECONDS || 30 * 60);
const imageTokenTtlSeconds = Number(process.env.IMAGE_TOKEN_TTL_SECONDS || 24 * 60 * 60);

let catalogCache;
let signingCredentialsCache;

async function loadCatalog() {
  if (!catalogCache || process.env.NODE_ENV !== "production") {
    const raw = await readFile(catalogPath, "utf8");
    catalogCache = JSON.parse(raw);
  }

  return catalogCache;
}

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  });
  res.end(JSON.stringify(body));
}

function sendRedirect(res, location) {
  res.writeHead(302, {
    Location: location,
    "Cache-Control": "no-store"
  });
  res.end();
}

function isPublished(item) {
  return item.status === "published";
}

function canIncludeHidden(url) {
  return process.env.NODE_ENV !== "production" && url.searchParams.get("includeHidden") === "1";
}

function isVisibleShow(show, includeHidden = false) {
  return isPublished(show) || (includeHidden && show.status === "hidden");
}

function publicEpisode(req, episode, show, imageUrl) {
  return {
    id: episode.id,
    showId: episode.showId,
    showTitle: show?.title,
    episodeNumber: episode.episodeNumber,
    title: episode.title,
    description: episode.description,
    durationSeconds: episode.durationSeconds,
    thumbnailUrl: imageUrl(episode, `/episodes/${episode.id}/thumbnail`),
    playbackPath: `/episodes/${episode.id}/playback`,
    isLocked: episode.isLocked,
    isFreePreview: episode.isFreePreview,
    publishedAt: episode.publishedAt
  };
}

function publicShow(req, show, episodeCount, imageUrl) {
  return {
    id: show.id,
    title: show.title,
    description: show.description,
    genre: show.genre,
    posterUrl: imageUrl({ posterUrl: show.posterUrl }, `/shows/${show.id}/poster`),
    coverUrl: imageUrl({ coverUrl: show.coverUrl }, `/shows/${show.id}/cover`),
    episodeCount
  };
}

function notFound(res) {
  sendJson(res, 404, { error: "not_found" });
}

function base64Url(input) {
  return Buffer.from(input).toString("base64url");
}

function absoluteUrl(req, path) {
  const protocol = req.headers["x-forwarded-proto"] || "http";
  const host = req.headers["x-forwarded-host"] || req.headers.host;
  return `${protocol}://${host}${path}`;
}

function cloudflareVideoUidFromUrl(value) {
  if (!value) {
    return null;
  }

  try {
    const url = new URL(value);
    const [, videoUid] = url.pathname.split("/");
    return videoUid || null;
  } catch {
    return null;
  }
}

function thumbnailVideoUid(item) {
  return item.providerAssetId || cloudflareVideoUidFromUrl(item.thumbnailUrl || item.posterUrl || item.coverUrl);
}

function normalizeSigningKey(value) {
  if (!value) {
    return null;
  }

  const trimmed = value.trim().replace(/^(['"`])([\s\S]*)\1$/, "$2");
  const normalizedPem = trimmed.replace(/\\n/g, "\n");
  const candidates = [normalizedPem];

  try {
    const decoded = Buffer.from(normalizedPem, "base64").toString("utf8").trim();
    if (decoded.includes("-----BEGIN") || decoded.startsWith("{")) {
      candidates.push(decoded.replace(/\\n/g, "\n"));
    }
  } catch {
    // Not base64-encoded key material.
  }

  let lastError;
  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (typeof parsed === "string") {
        return normalizeSigningKey(parsed);
      }

      return createPrivateKey({
        key: parsed,
        format: "jwk"
      });
    } catch (error) {
      lastError = error;
    }

    try {
      return createPrivateKey(candidate);
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError;
}

function normalizeBearerToken(value) {
  return value?.trim().replace(/^Bearer\s+/i, "");
}

function getStreamSigningCredentials() {
  const keyId = process.env.CLOUDFLARE_STREAM_SIGNING_KEY_ID;
  const rawPrivateKey = process.env.CLOUDFLARE_STREAM_SIGNING_PRIVATE_KEY;

  if (!keyId || !rawPrivateKey) {
    return null;
  }

  if (
    signingCredentialsCache?.keyId === keyId &&
    signingCredentialsCache?.rawPrivateKey === rawPrivateKey
  ) {
    return signingCredentialsCache.credentials;
  }

  const credentials = {
    keyId,
    privateKey: normalizeSigningKey(rawPrivateKey)
  };

  signingCredentialsCache = {
    keyId,
    rawPrivateKey,
    credentials
  };

  return credentials;
}

function generateCloudflareStreamToken(videoUid, ttlSeconds = playbackTokenTtlSeconds) {
  const credentials = getStreamSigningCredentials();

  if (!credentials) {
    return null;
  }

  const { keyId, privateKey } = credentials;
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "RS256",
    kid: keyId,
    typ: "JWT"
  };
  const payload = {
    sub: videoUid,
    kid: keyId,
    nbf: now - 30,
    exp: now + ttlSeconds
  };
  const signingInput = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}`;
  const signature = createSign("RSA-SHA256").update(signingInput).sign(privateKey).toString("base64url");

  return {
    token: `${signingInput}.${signature}`,
    expiresAt: new Date(payload.exp * 1000).toISOString()
  };
}

async function fetchCloudflareStreamToken(videoUid) {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const apiToken = normalizeBearerToken(process.env.CLOUDFLARE_STREAM_API_TOKEN);

  if (!accountId || !apiToken) {
    return null;
  }

  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${videoUid}/token`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiToken}`
      }
    }
  );

  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.success || !body.result?.token) {
    throw new Error(`Cloudflare Stream token request failed with ${response.status}`);
  }

  return {
    token: body.result.token,
    expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString()
  };
}

async function buildCloudflareStreamToken(videoUid, ttlSeconds = playbackTokenTtlSeconds) {
  let ticket = generateCloudflareStreamToken(videoUid, ttlSeconds);
  if (!ticket) {
    ticket = await fetchCloudflareStreamToken(videoUid);
  }

  return ticket;
}

async function buildCloudflareAssetUrl(videoUid, assetPath, ttlSeconds = playbackTokenTtlSeconds) {
  const ticket = await buildCloudflareStreamToken(videoUid, ttlSeconds);

  if (!ticket) {
    const error = new Error("Cloudflare Stream signing is not configured");
    error.statusCode = 503;
    throw error;
  }

  return {
    url: `https://videodelivery.net/${ticket.token}${assetPath}`,
    expiresAt: ticket.expiresAt
  };
}

function buildLocallySignedCloudflareAssetUrl(videoUid, assetPath, ttlSeconds = playbackTokenTtlSeconds) {
  const ticket = generateCloudflareStreamToken(videoUid, ttlSeconds);

  if (!ticket) {
    return null;
  }

  return `https://videodelivery.net/${ticket.token}${assetPath}`;
}

function createImageUrlBuilder(req) {
  const urlsByVideoUid = new Map();

  return function imageUrl(item, fallbackPath) {
    const videoUid = thumbnailVideoUid(item);
    if (!videoUid) {
      return absoluteUrl(req, fallbackPath);
    }

    if (!urlsByVideoUid.has(videoUid)) {
      urlsByVideoUid.set(
        videoUid,
        buildLocallySignedCloudflareAssetUrl(videoUid, "/thumbnails/thumbnail.jpg", imageTokenTtlSeconds) ||
          absoluteUrl(req, fallbackPath)
      );
    }

    return urlsByVideoUid.get(videoUid);
  };
}

async function buildPlaybackTicket(episode) {
  if (episode.provider !== "cloudflare_stream" || !episode.providerAssetId) {
    throw new Error(`Unsupported playback provider for episode ${episode.id}`);
  }

  const asset = await buildCloudflareAssetUrl(
    episode.providerAssetId,
    "/manifest/video.m3u8"
  );

  return {
    playbackUrl: asset.url,
    expiresAt: asset.expiresAt
  };
}

async function buildThumbnailTicket(item) {
  const videoUid = thumbnailVideoUid(item);
  if (!videoUid) {
    const error = new Error("Cloudflare Stream thumbnail asset is not configured");
    error.statusCode = 404;
    throw error;
  }

  return buildCloudflareAssetUrl(videoUid, "/thumbnails/thumbnail.jpg", imageTokenTtlSeconds);
}

function logPlaybackTicketRequest(req, episode, ticket) {
  console.log(
    JSON.stringify({
      event: "playback_ticket_issued",
      episodeId: episode.id,
      provider: episode.provider,
      providerAssetId: episode.providerAssetId,
      expiresAt: ticket.expiresAt,
      ip: req.headers["x-forwarded-for"] || req.socket.remoteAddress,
      userAgent: req.headers["user-agent"] || null,
      requestedAt: new Date().toISOString()
    })
  );
}

async function handleRequest(req, res) {
  if (req.method === "OPTIONS") {
    sendJson(res, 204, {});
    return;
  }

  if (req.method !== "GET") {
    sendJson(res, 405, { error: "method_not_allowed" });
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  try {
    const catalog = await loadCatalog();
    const includeHidden = canIncludeHidden(url);
    const shows = catalog.shows
      .filter((show) => isVisibleShow(show, includeHidden))
      .sort((a, b) => a.sortOrder - b.sortOrder);
    const showsById = new Map(shows.map((show) => [show.id, show]));
    const visibleShowIds = new Set(showsById.keys());
    const episodes = catalog.episodes.filter((episode) => isPublished(episode) && visibleShowIds.has(episode.showId));
    const episodesById = new Map(episodes.map((episode) => [episode.id, episode]));
    const imageUrl = createImageUrlBuilder(req);

    if (path === "/health") {
      sendJson(res, 200, { ok: true });
      return;
    }

    if (path === "/config") {
      sendJson(res, 200, catalog.app);
      return;
    }

    if (path === "/shows") {
      sendJson(
        res,
        200,
        shows.map((show) => {
          const episodeCount = episodes.filter((episode) => episode.showId === show.id).length;
          return publicShow(req, show, episodeCount, imageUrl);
        })
      );
      return;
    }

    const showMatch = path.match(/^\/shows\/([^/]+)$/);
    if (showMatch) {
      const show = showsById.get(showMatch[1]);
      if (!show) {
        notFound(res);
        return;
      }

      const showEpisodes = episodes
        .filter((episode) => episode.showId === show.id)
        .sort((a, b) => a.episodeNumber - b.episodeNumber);

      sendJson(res, 200, {
        ...publicShow(req, show, showEpisodes.length, imageUrl),
        episodes: showEpisodes.map((episode) => publicEpisode(req, episode, show, imageUrl))
      });
      return;
    }

    const showPosterMatch = path.match(/^\/shows\/([^/]+)\/poster$/);
    if (showPosterMatch) {
      const show = showsById.get(showPosterMatch[1]);
      if (!show) {
        notFound(res);
        return;
      }

      const ticket = await buildThumbnailTicket({ posterUrl: show.posterUrl });
      sendRedirect(res, ticket.url);
      return;
    }

    const showCoverMatch = path.match(/^\/shows\/([^/]+)\/cover$/);
    if (showCoverMatch) {
      const show = showsById.get(showCoverMatch[1]);
      if (!show) {
        notFound(res);
        return;
      }

      const ticket = await buildThumbnailTicket({ coverUrl: show.coverUrl });
      sendRedirect(res, ticket.url);
      return;
    }

    const showEpisodesMatch = path.match(/^\/shows\/([^/]+)\/episodes$/);
    if (showEpisodesMatch) {
      const show = showsById.get(showEpisodesMatch[1]);
      if (!show) {
        notFound(res);
        return;
      }

      const showEpisodes = episodes
        .filter((episode) => episode.showId === show.id)
        .sort((a, b) => a.episodeNumber - b.episodeNumber)
        .map((episode) => publicEpisode(req, episode, show, imageUrl));

      sendJson(res, 200, showEpisodes);
      return;
    }

    const episodeMatch = path.match(/^\/episodes\/([^/]+)$/);
    if (episodeMatch) {
      const episode = episodesById.get(episodeMatch[1]);
      if (!episode) {
        notFound(res);
        return;
      }

      sendJson(res, 200, publicEpisode(req, episode, showsById.get(episode.showId), imageUrl));
      return;
    }

    const episodeThumbnailMatch = path.match(/^\/episodes\/([^/]+)\/thumbnail$/);
    if (episodeThumbnailMatch) {
      const episode = episodesById.get(episodeThumbnailMatch[1]);
      if (!episode) {
        notFound(res);
        return;
      }

      const ticket = await buildThumbnailTicket(episode);
      sendRedirect(res, ticket.url);
      return;
    }

    const playbackMatch = path.match(/^\/episodes\/([^/]+)\/playback$/);
    if (playbackMatch) {
      const episode = episodesById.get(playbackMatch[1]);
      if (!episode) {
        notFound(res);
        return;
      }

      const ticket = await buildPlaybackTicket(episode);
      logPlaybackTicketRequest(req, episode, ticket);
      sendJson(res, 200, ticket);
      return;
    }

    if (path === "/feed") {
      const feedId = url.searchParams.get("feed") || catalog.app.defaultFeed;
      const feed = catalog.feeds.find((candidate) => candidate.id === feedId);
      if (!feed) {
        notFound(res);
        return;
      }

      const feedEpisodes = feed.episodeIds
        .map((episodeId) => episodesById.get(episodeId))
        .filter(Boolean)
        .map((episode) => publicEpisode(req, episode, showsById.get(episode.showId), imageUrl));

      sendJson(res, 200, {
        id: feed.id,
        title: feed.title,
        episodes: feedEpisodes
      });
      return;
    }

    notFound(res);
  } catch (error) {
    console.error(error);
    sendJson(res, error.statusCode || 500, { error: "internal_server_error" });
  }
}

createServer(handleRequest).listen(port, () => {
  console.log(`Micro Drama API listening on :${port}`);
});
