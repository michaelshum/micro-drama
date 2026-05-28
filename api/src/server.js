import { createServer } from "node:http";
import { createSign } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(__dirname, "..", "data", "catalog.json");
const port = Number(process.env.PORT || 3000);
const playbackTokenTtlSeconds = Number(process.env.PLAYBACK_TOKEN_TTL_SECONDS || 30 * 60);

let catalogCache;

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

function isPublished(item) {
  return item.status === "published";
}

function publicEpisode(episode, show) {
  return {
    id: episode.id,
    showId: episode.showId,
    showTitle: show?.title,
    episodeNumber: episode.episodeNumber,
    title: episode.title,
    description: episode.description,
    durationSeconds: episode.durationSeconds,
    thumbnailUrl: episode.thumbnailUrl,
    playbackPath: `/episodes/${episode.id}/playback`,
    isLocked: episode.isLocked,
    isFreePreview: episode.isFreePreview,
    publishedAt: episode.publishedAt
  };
}

function publicShow(show, episodeCount) {
  return {
    id: show.id,
    title: show.title,
    description: show.description,
    genre: show.genre,
    posterUrl: show.posterUrl,
    coverUrl: show.coverUrl,
    episodeCount
  };
}

function notFound(res) {
  sendJson(res, 404, { error: "not_found" });
}

function base64Url(input) {
  return Buffer.from(input).toString("base64url");
}

function normalizePrivateKey(value) {
  return value?.replace(/\\n/g, "\n");
}

function generateCloudflareStreamToken(videoUid) {
  const keyId = process.env.CLOUDFLARE_STREAM_SIGNING_KEY_ID;
  const privateKey = normalizePrivateKey(process.env.CLOUDFLARE_STREAM_SIGNING_PRIVATE_KEY);

  if (!keyId || !privateKey) {
    return null;
  }

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
    exp: now + playbackTokenTtlSeconds
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
  const apiToken = process.env.CLOUDFLARE_STREAM_API_TOKEN;

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

async function buildPlaybackTicket(episode) {
  if (episode.provider !== "cloudflare_stream" || !episode.providerAssetId) {
    throw new Error(`Unsupported playback provider for episode ${episode.id}`);
  }

  let ticket = generateCloudflareStreamToken(episode.providerAssetId);
  if (!ticket) {
    ticket = await fetchCloudflareStreamToken(episode.providerAssetId);
  }

  if (!ticket) {
    if (process.env.ALLOW_UNSIGNED_PLAYBACK === "true" && episode.playbackUrl) {
      return {
        playbackUrl: episode.playbackUrl,
        expiresAt: null
      };
    }

    const error = new Error("Cloudflare Stream signing is not configured");
    error.statusCode = 503;
    throw error;
  }

  return {
    playbackUrl: `https://videodelivery.net/${ticket.token}/manifest/video.m3u8`,
    expiresAt: ticket.expiresAt
  };
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
    const shows = catalog.shows.filter(isPublished).sort((a, b) => a.sortOrder - b.sortOrder);
    const episodes = catalog.episodes.filter(isPublished);
    const showsById = new Map(shows.map((show) => [show.id, show]));
    const episodesById = new Map(episodes.map((episode) => [episode.id, episode]));

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
          return publicShow(show, episodeCount);
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
        ...publicShow(show, showEpisodes.length),
        episodes: showEpisodes.map((episode) => publicEpisode(episode, show))
      });
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
        .map((episode) => publicEpisode(episode, show));

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

      sendJson(res, 200, publicEpisode(episode, showsById.get(episode.showId)));
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
        .map((episode) => publicEpisode(episode, showsById.get(episode.showId)));

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
