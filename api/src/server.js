import { createServer } from "node:http";
import { createPrivateKey, createSign } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(__dirname, "..", "data", "catalog.json");
const tasteAnchorPostersPath = join(__dirname, "..", "data", "taste-anchor-posters");
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
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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

function sendJpeg(res, body) {
  res.writeHead(200, {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "image/jpeg",
    "Cache-Control": "public, max-age=86400"
  });
  res.end(body);
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

const heroTraitLabels = new Map([
  ["absurd", "Absurd"],
  ["billionaire-lover", "Billionaire"],
  ["boss-subordinate", "Boss Romance"],
  ["cartoon-3d", "Cartoon 3D"],
  ["cliffhanger-ending", "Cliffhangers"],
  ["cliffhanger-heavy", "Cliffhangers"],
  ["competitive", "Competitive"],
  ["competitive-dating", "Competitive Dating"],
  ["constant-reversals", "Twists"],
  ["dating-competition", "Dating Show"],
  ["dating-game", "Dating Show"],
  ["dating-show", "Dating Show"],
  ["dramatic", "Dramatic"],
  ["enemies-to-lovers", "Enemies to Lovers"],
  ["flirty", "Flirty"],
  ["forbidden-affair", "Forbidden Love"],
  ["glamorous", "Glamorous"],
  ["jealousy-spiral", "Jealousy"],
  ["love-triangle", "Love Triangles"],
  ["new-arrival-disruption", "New Arrivals"],
  ["quick-romantic-spark", "Quick Sparks"],
  ["recoupling", "Recoupling"],
  ["revenge", "Revenge"],
  ["revenge-trap", "Revenge"],
  ["romantic", "Romantic"],
  ["second-chance", "Second Chance"],
  ["secret-identity", "Secret Identity"],
  ["tense", "Tense"],
  ["villa-romance", "Villa Romance"],
  ["wealth-gap", "Wealth Gap"]
]);

function uniqueNonEmptyStrings(values) {
  return [...new Set((Array.isArray(values) ? values : []).filter((value) => typeof value === "string").map((value) => value.trim()).filter(Boolean))];
}

function heroTraitsForShow(show) {
  const recommendation = show.recommendation || {};
  const curatedTraits = uniqueNonEmptyStrings(recommendation.heroTraits);
  if (curatedTraits.length > 0) {
    return curatedTraits.slice(0, 4);
  }

  const sourceTags = [
    ...(recommendation.tone || []),
    ...(recommendation.microGenres || []),
    ...(recommendation.relationshipDynamics || []),
    ...(recommendation.storySignals || []),
    ...(recommendation.pacingPromises || [])
  ];

  const traits = [];
  for (const tag of sourceTags) {
    const label = heroTraitLabels.get(tag);
    if (label && !traits.includes(label)) {
      traits.push(label);
    }

    if (traits.length >= 4) {
      break;
    }
  }

  return traits;
}

function publicShow(req, show, episodeCount, imageUrl, representativeEpisode = null) {
  const representativeThumbnailUrl = representativeEpisode
    ? imageUrl(representativeEpisode, `/episodes/${representativeEpisode.id}/thumbnail`)
    : imageUrl({ posterUrl: show.posterUrl }, `/shows/${show.id}/poster`);

  return {
    id: show.id,
    title: show.title,
    description: show.description,
    genre: show.genre,
    thumbnailUrl: representativeThumbnailUrl,
    posterUrl: imageUrl({ posterUrl: show.posterUrl }, `/shows/${show.id}/poster`),
    coverUrl: imageUrl({ coverUrl: show.coverUrl }, `/shows/${show.id}/cover`),
    heroTraits: heroTraitsForShow(show),
    episodeCount
  };
}

function notFound(res) {
  sendJson(res, 404, { error: "not_found" });
}

function readJsonBody(req, maxBytes = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let raw = "";

    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > maxBytes) {
        const error = new Error("Request body too large");
        error.statusCode = 413;
        reject(error);
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!raw.trim()) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(raw));
      } catch {
        const error = new Error("Invalid JSON request body");
        error.statusCode = 400;
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function uniqueStrings(values) {
  const seen = new Set();
  return (Array.isArray(values) ? values : []).filter((value) => {
    if (typeof value !== "string" || seen.has(value)) {
      return false;
    }

    seen.add(value);
    return true;
  });
}

function shouldShowTasteAnchorPosters(homeConfig) {
  return homeConfig?.tasteAnchorArtworkMode === "poster";
}

function publicTasteAnchor(req, anchor, shouldShowPoster, visibleShowIds = null) {
  const preferredShowIds = uniqueStrings(anchor.preferredShowIds)
    .filter((showId) => !visibleShowIds || visibleShowIds.has(showId));

  const publicAnchor = {
    id: anchor.id,
    title: anchor.title,
    emoji: typeof anchor.emoji === "string" ? anchor.emoji : null,
    preferredShowIds
  };

  if (shouldShowPoster) {
    publicAnchor.posterUrl = absoluteUrl(req, `/taste-anchors/${anchor.id}/poster`);
  }

  return publicAnchor;
}

function buildTasteAnchors(req, homeConfig, visibleShowIds = null) {
  const anchors = Array.isArray(homeConfig.tasteAnchors) ? homeConfig.tasteAnchors : [];
  const shouldShowPoster = shouldShowTasteAnchorPosters(homeConfig);
  return anchors.map((anchor) => publicTasteAnchor(req, anchor, shouldShowPoster, visibleShowIds));
}

async function sendTasteAnchorPoster(res, anchorId) {
  if (!/^[A-Za-z0-9_-]+$/.test(anchorId)) {
    notFound(res);
    return;
  }

  try {
    const poster = await readFile(join(tasteAnchorPostersPath, `${anchorId}.jpg`));
    sendJpeg(res, poster);
  } catch {
    notFound(res);
  }
}

function publicShowsFromIds(showIds, showsById, episodeCountsByShowId, firstEpisodesByShowId, imageUrl) {
  return uniqueStrings(showIds)
    .map((showId) => showsById.get(showId))
    .filter(Boolean)
    .map((show) => publicShow(
      null,
      show,
      episodeCountsByShowId.get(show.id) || 0,
      imageUrl,
      firstEpisodesByShowId.get(show.id)
    ));
}

function firstPlayableEpisodeForShow(showId, episodes) {
  return episodes
    .filter((episode) => episode.showId === showId)
    .sort((a, b) => a.episodeNumber - b.episodeNumber)
    .find((episode) => !episode.isLocked);
}

function recommendationTags(show) {
  const recommendation = show?.recommendation || {};
  return uniqueStrings([
    recommendation.primaryGenre,
    ...(recommendation.heroTraits || []),
    ...(recommendation.microGenres || []),
    ...(recommendation.storySignals || []),
    ...(recommendation.storyDrivers || []),
    ...(recommendation.tropes || []),
    ...(recommendation.tone || []),
    ...(recommendation.relationshipDynamics || []),
    ...(recommendation.pacingPromises || [])
  ].filter(Boolean));
}

function homeSectionRank(homeConfig) {
  const ranks = new Map();
  let rank = 0;

  for (const section of homeConfig.sections || []) {
    for (const showId of section.showIds || []) {
      if (!ranks.has(showId)) {
        ranks.set(showId, rank);
        rank += 1;
      }
    }
  }

  return ranks;
}

function rankedRecommendationCandidates(
  homeConfig,
  sourceShow,
  requestBody,
  shows,
  episodes
) {
  const activeShowIds = new Set(uniqueStrings(requestBody?.activeShowIds));
  const completedShowIds = new Set(uniqueStrings(requestBody?.completedShowIds));
  const excludedShowIds = new Set([
    sourceShow.id,
    ...activeShowIds,
    ...completedShowIds
  ]);
  const sourceSimilarShowIds = uniqueStrings(sourceShow.recommendation?.similarShowIds);
  const onboarding = requestBody?.onboarding || {};
  const onboardingMatchedShowId = typeof onboarding.matchedShowId === "string" ? onboarding.matchedShowId : null;
  const onboardingAlternateShowIds = uniqueStrings(onboarding.alternateShowIds);
  const selectedAnchorIds = uniqueStrings(onboarding.selectedAnchorIds);
  const anchorsById = new Map((homeConfig.tasteAnchors || []).map((anchor) => [anchor.id, anchor]));
  const anchorPreferredShowIds = [];
  for (const anchorId of selectedAnchorIds) {
    anchorPreferredShowIds.push(...uniqueStrings(anchorsById.get(anchorId)?.preferredShowIds));
  }

  const sourceTags = new Set(recommendationTags(sourceShow));
  const sectionRanks = homeSectionRank(homeConfig);
  const candidates = [];

  for (const show of shows) {
    if (excludedShowIds.has(show.id)) {
      continue;
    }

    const firstPlayableEpisode = firstPlayableEpisodeForShow(show.id, episodes);
    if (!firstPlayableEpisode) {
      continue;
    }

    let score = 0;
    const similarIndex = sourceSimilarShowIds.indexOf(show.id);
    if (similarIndex >= 0) {
      score += 100 - similarIndex;
    }

    if (show.id === onboardingMatchedShowId) {
      score += 80;
    }

    const alternateIndex = onboardingAlternateShowIds.indexOf(show.id);
    if (alternateIndex >= 0) {
      score += 70 - alternateIndex;
    }

    const anchorIndex = anchorPreferredShowIds.indexOf(show.id);
    if (anchorIndex >= 0) {
      score += 60 - anchorIndex;
    }

    for (const tag of recommendationTags(show)) {
      if (sourceTags.has(tag)) {
        score += 3;
      }
    }

    const sectionRank = sectionRanks.get(show.id);
    if (sectionRank !== undefined) {
      score += Math.max(1, 40 - sectionRank);
    }

    score += Math.max(0, 20 - (show.sortOrder || 0));

    candidates.push({
      show,
      firstPlayableEpisode,
      score
    });
  }

  candidates.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }

    return (a.show.sortOrder || 0) - (b.show.sortOrder || 0);
  });

  return candidates;
}

function buildRecommendationPayload(recommendation, episodeCountsByShowId, firstEpisodesByShowId, imageUrl) {
  return {
    show: publicShow(
      null,
      recommendation.show,
      episodeCountsByShowId.get(recommendation.show.id) || 0,
      imageUrl,
      firstEpisodesByShowId.get(recommendation.show.id)
    ),
    episodeId: recommendation.firstPlayableEpisode.id
  };
}

function buildEndOfShowRecommendation(
  homeConfig,
  requestBody,
  shows,
  showsById,
  episodes,
  episodeCountsByShowId,
  firstEpisodesByShowId,
  imageUrl
) {
  const sourceShow = showsById.get(requestBody?.sourceShowId);
  if (!sourceShow) {
    return null;
  }

  const recommendation = rankedRecommendationCandidates(homeConfig, sourceShow, requestBody, shows, episodes)[0];
  if (!recommendation) {
    return null;
  }

  return buildRecommendationPayload(recommendation, episodeCountsByShowId, firstEpisodesByShowId, imageUrl);
}

function buildMoreLikeThisRecommendations(
  homeConfig,
  sourceShow,
  requestBody,
  shows,
  episodes,
  episodeCountsByShowId,
  firstEpisodesByShowId,
  imageUrl,
  limit = 12
) {
  return rankedRecommendationCandidates(homeConfig, sourceShow, requestBody, shows, episodes)
    .slice(0, limit)
    .map((recommendation) => buildRecommendationPayload(
      recommendation,
      episodeCountsByShowId,
      firstEpisodesByShowId,
      imageUrl
    ));
}

function buildBecauseYouLikeSection(
  homeConfig,
  requestBody,
  showsById,
  episodeCountsByShowId,
  firstEpisodesByShowId,
  imageUrl,
  excludedShowIds
) {
  const selectedAnchorIds = uniqueStrings(requestBody?.onboarding?.selectedAnchorIds);
  const anchorsById = new Map((homeConfig.tasteAnchors || []).map((anchor) => [anchor.id, anchor]));

  for (const anchorId of selectedAnchorIds) {
    const anchor = anchorsById.get(anchorId);
    if (!anchor) {
      continue;
    }

    const shows = publicShowsFromIds(
      anchor.preferredShowIds?.filter((showId) => !excludedShowIds.has(showId)),
      showsById,
      episodeCountsByShowId,
      firstEpisodesByShowId,
      imageUrl
    );

    if (shows.length > 0) {
      return {
        id: `because-you-like-${anchor.id}`,
        title: `Because you like ${anchor.title}`,
        shows
      };
    }
  }

  return null;
}

function continueWatchingThumbnailsForRequest(requestBody, episodesById, imageUrl) {
  return (Array.isArray(requestBody?.continueWatchingEpisodes) ? requestBody.continueWatchingEpisodes : [])
    .map((item) => {
      if (!item || typeof item.showId !== "string" || typeof item.episodeId !== "string") {
        return null;
      }

      const episode = episodesById.get(item.episodeId);
      if (!episode || episode.showId !== item.showId) {
        return null;
      }

      return {
        showId: item.showId,
        episodeId: item.episodeId,
        thumbnailUrl: imageUrl(episode, `/episodes/${episode.id}/thumbnail`)
      };
    })
    .filter(Boolean);
}

function buildHomeResponse(homeConfig, requestBody, shows, showsById, episodesById, episodeCountsByShowId, firstEpisodesByShowId, imageUrl) {
  const excludedShowIds = new Set(uniqueStrings(requestBody?.excludedShowIds));
  const heroExcludedShowIds = new Set([
    ...excludedShowIds,
    ...uniqueStrings(requestBody?.heroExcludedShowIds)
  ]);
  const usedShowIds = new Set(excludedShowIds);
  const sections = [];
  const becauseYouLikeSection = buildBecauseYouLikeSection(
    homeConfig,
    requestBody,
    showsById,
    episodeCountsByShowId,
    firstEpisodesByShowId,
    imageUrl,
    usedShowIds
  );

  if (becauseYouLikeSection) {
    sections.push(becauseYouLikeSection);
    for (const show of becauseYouLikeSection.shows) {
      usedShowIds.add(show.id);
    }
  }

  for (const section of homeConfig.sections || []) {
    const sectionShowIds = (section.showIds || []).filter((showId) => !usedShowIds.has(showId));
    const sectionShows = publicShowsFromIds(sectionShowIds, showsById, episodeCountsByShowId, firstEpisodesByShowId, imageUrl);
    if (sectionShows.length === 0) {
      continue;
    }

    sections.push({
      id: section.id,
      title: section.title,
      shows: sectionShows
    });

    for (const show of sectionShows) {
      usedShowIds.add(show.id);
    }
  }

  const heroShow =
    sections.flatMap((section) => section.shows)
      .map((show) => showsById.get(show.id))
      .find((show) => show && !heroExcludedShowIds.has(show.id)) ||
    shows.find((show) => !heroExcludedShowIds.has(show.id));

  return {
    heroShow: heroShow ? publicShow(
      null,
      heroShow,
      episodeCountsByShowId.get(heroShow.id) || 0,
      imageUrl,
      firstEpisodesByShowId.get(heroShow.id)
    ) : null,
    sections,
    continueWatchingThumbnails: continueWatchingThumbnailsForRequest(requestBody, episodesById, imageUrl)
  };
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
      const signedUrl = buildLocallySignedCloudflareAssetUrl(videoUid, "/thumbnails/thumbnail.jpg", imageTokenTtlSeconds);
      if (!signedUrl) {
        return absoluteUrl(req, fallbackPath);
      }

      urlsByVideoUid.set(videoUid, signedUrl);
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

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  const allowsPost =
    path === "/home" ||
    path === "/recommendations/end-of-show" ||
    /^\/shows\/[^/]+\/more-like-this$/.test(path);
  if (req.method !== "GET" && !(req.method === "POST" && allowsPost)) {
    sendJson(res, 405, { error: "method_not_allowed" });
    return;
  }

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
    const episodeCountsByShowId = new Map();
    for (const episode of episodes) {
      episodeCountsByShowId.set(episode.showId, (episodeCountsByShowId.get(episode.showId) || 0) + 1);
    }
    const firstEpisodesByShowId = new Map();
    for (const episode of episodes) {
      const current = firstEpisodesByShowId.get(episode.showId);
      if (!current || episode.episodeNumber < current.episodeNumber) {
        firstEpisodesByShowId.set(episode.showId, episode);
      }
    }
    const imageUrl = createImageUrlBuilder(req);

    if (path === "/health") {
      sendJson(res, 200, { ok: true });
      return;
    }

    if (path === "/config") {
      sendJson(res, 200, catalog.app);
      return;
    }

    if (path === "/taste-anchors") {
      sendJson(res, 200, buildTasteAnchors(req, catalog.home || {}, visibleShowIds));
      return;
    }

    const tasteAnchorPosterMatch = path.match(/^\/taste-anchors\/([^/]+)\/poster$/);
    if (tasteAnchorPosterMatch) {
      if (!shouldShowTasteAnchorPosters(catalog.home || {})) {
        notFound(res);
        return;
      }

      await sendTasteAnchorPoster(res, tasteAnchorPosterMatch[1]);
      return;
    }

    if (path === "/home" && req.method === "POST") {
      const requestBody = await readJsonBody(req);
      sendJson(
        res,
        200,
        buildHomeResponse(catalog.home || {}, requestBody, shows, showsById, episodesById, episodeCountsByShowId, firstEpisodesByShowId, imageUrl)
      );
      return;
    }

    if (path === "/recommendations/end-of-show" && req.method === "POST") {
      const requestBody = await readJsonBody(req);
      const recommendation = buildEndOfShowRecommendation(
        catalog.home || {},
        requestBody,
        shows,
        showsById,
        episodes,
        episodeCountsByShowId,
        firstEpisodesByShowId,
        imageUrl
      );

      if (!recommendation) {
        sendJson(res, 404, { error: "not_found" });
        return;
      }

      sendJson(res, 200, recommendation);
      return;
    }

    const moreLikeThisMatch = path.match(/^\/shows\/([^/]+)\/more-like-this$/);
    if (moreLikeThisMatch && req.method === "POST") {
      const show = showsById.get(moreLikeThisMatch[1]);
      if (!show) {
        notFound(res);
        return;
      }

      const requestBody = await readJsonBody(req);
      sendJson(
        res,
        200,
        buildMoreLikeThisRecommendations(
          catalog.home || {},
          show,
          requestBody,
          shows,
          episodes,
          episodeCountsByShowId,
          firstEpisodesByShowId,
          imageUrl
        )
      );
      return;
    }

    if (path === "/shows") {
      sendJson(
        res,
        200,
        shows.map((show) => {
          return publicShow(
            req,
            show,
            episodeCountsByShowId.get(show.id) || 0,
            imageUrl,
            firstEpisodesByShowId.get(show.id)
          );
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
        ...publicShow(req, show, showEpisodes.length, imageUrl, firstEpisodesByShowId.get(show.id)),
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
  console.log(`Onda API listening on :${port}`);
});
