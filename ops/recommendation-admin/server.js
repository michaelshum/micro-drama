import { createServer } from "node:http";
import { createPrivateKey, createSign } from "node:crypto";
import { readFile, rename, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");
const catalogPath = process.env.CATALOG_PATH
  ? resolve(process.env.CATALOG_PATH)
  : join(repoRoot, "api/data/catalog.json");
const optionsPath = process.env.OPTIONS_PATH
  ? resolve(process.env.OPTIONS_PATH)
  : join(repoRoot, "api/data/recommendation-options.json");
const publicDir = join(__dirname, "public");
const port = Number(process.env.PORT || 3015);
const host = process.env.HOST || "127.0.0.1";
const playbackTokenTtlSeconds = Number(process.env.PLAYBACK_TOKEN_TTL_SECONDS || 30 * 60);
const imageTokenTtlSeconds = Number(process.env.IMAGE_TOKEN_TTL_SECONDS || 24 * 60 * 60);

let signingCredentialsCache;

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml"
};

const emptyRecommendation = {
  primaryGenre: "",
  heroTraits: [],
  secondaryGenres: [],
  microGenres: [],
  storySignals: [],
  storyDrivers: [],
  tropes: [],
  tone: [],
  emotionalFantasies: [],
  protagonistArchetypes: [],
  counterpartArchetypes: [],
  relationshipDynamics: [],
  conflictSetups: [],
  powerDynamics: [],
  payoffTypes: [],
  pacingPromises: [],
  endingPromises: [],
  setting: [],
  characterSystem: [],
  worldType: [],
  visualStyle: [],
  contentLineage: {
    type: ""
  },
  referenceSignals: [],
  format: {
    episodeLengthBucket: "",
    serialization: "",
    cliffhangerLevel: "",
    freePreviewEpisodes: 0
  },
  audience: {
    maturityRating: "",
    language: "en",
    contentWarnings: []
  },
  release: {
    freshnessWindowDays: 14
  },
  editorial: {
    qualityLabel: 4,
    qualityScore: 0.7,
    coldStartPriority: 5,
    featuredBoost: 1
  },
  similarShowIds: []
};

const emptyEpisodeRecommendation = {
  scriptNotes: "",
  activeAtoms: [],
  emotionalBeat: "",
  narrativeRole: "",
  payoffTypes: [],
  pacingTags: []
};

const defaultRecommendationOptions = {
  heroTraits: ["Flirty", "Dramatic", "Absurd", "Love Triangles", "Dating Show", "Recoupling", "Cliffhangers", "Billionaire", "Revenge", "Forbidden Love", "Enemies to Lovers", "Second Chance", "Secret Identity", "Tense", "Glamorous", "Cartoon 3D"],
  primaryGenre: ["romance", "drama", "comedy", "thriller", "fantasy", "crime", "sports", "action", "horror", "sci-fi", "reality-style"],
  secondaryGenres: ["reality-style", "competition", "melodrama", "satire", "parody", "soap-opera", "rom-com", "light-comedy", "sports-drama", "crime-drama", "fantasy-adventure", "historical", "workplace", "teen", "family-drama"],
  microGenres: ["dating-competition", "dating-show", "billionaire-romance", "class-gap-romance", "sports-underdog", "fashion-satire", "fantasy-parody", "crime-parody", "alternate-history", "war-fantasy", "reality-competition", "villa-romance"],
  storySignals: ["billionaire-lover", "power-imbalance", "luxury-life", "heartbreak", "fish-out-of-water", "romantic-pursuit", "wealth-gap", "secret-keeping", "mystery-reveal", "personal-transformation", "recognition-hook", "one-night-stand", "morning-after-shock", "anonymous-connection", "keepsake-token", "he-never-forgot-her", "forced-proximity", "protective-distance", "business-rescue", "lost-connection-reunion", "dating-game", "partner-selection", "recoupling", "public-vote", "elimination-pressure", "confessional-interviews", "new-arrival-disruption", "love-triangle", "couple-switching", "jealousy-spiral", "viewer-choice", "betrayed-wife", "cheating-husband", "mistress-takedown", "financial-exploitation", "hidden-knowledge-advantage", "evidence-gathering", "revenge-trap", "glow-up-transformation", "wife-secretly-knows", "villain-thinks-he-is-safe", "parody-recognition", "fashion-remix", "prestige-show-remix", "wizard-fantasy-remix", "sports-underdog", "training-grind", "team-competition", "war-fantasy", "alternate-history"],
  storyDrivers: ["romantic-pursuit", "partner-selection", "contest-progression", "elimination-pressure", "social-strategy", "betrayal", "revenge", "status-climbing", "wealth-gap", "secret-keeping", "mystery-reveal", "survival-pressure", "family-duty", "power-struggle", "personal-transformation", "recognition-hook", "rivalry-escalation"],
  tropes: ["love-triangle", "rivalry", "choice-driven", "elimination", "confessional-interviews", "forbidden-love", "chosen-one", "antihero", "makeover", "secret-identity", "underdog", "fish-out-of-water", "power-struggle", "billionaire-lover", "secret-affair", "power-imbalance", "luxury-life"],
  tone: ["playful", "flirty", "dramatic", "melodramatic", "dark", "tense", "absurd", "glamorous", "heartfelt", "chaotic", "suspenseful", "sexy"],
  emotionalFantasies: ["revenge-glow-up", "public-vindication", "chosen-over-rival", "romantic-validation", "status-transformation", "luxury-escape", "forbidden-desire", "underdog-triumph", "justice-served", "family-restoration", "power-fantasy", "social-domination", "second-chance-healing", "dangerous-desire", "survival-against-odds", "recognition-and-fame", "secret-power-reveal", "beautiful-life-upgrade", "humiliation-reversal", "being-protected"],
  protagonistArchetypes: ["betrayed-spouse", "strong-heroine", "naive-outsider", "ambitious-underdog", "hidden-heir", "hidden-heiress", "single-parent", "fallen-heiress", "bullied-outcast", "rebellious-princess", "reluctant-hero", "gifted-rookie", "disgraced-star", "ordinary-person-chosen", "survivor", "schemer", "comic-underdog", "flirty-contestant", "romantic-underdog"],
  counterpartArchetypes: ["cold-billionaire", "regretful-ex", "protective-alpha", "toxic-heartthrob", "secretly-soft-ceo", "arrogant-rival", "public-mistress", "villainous-family", "demanding-coach", "crime-boss", "dark-lord", "elite-mean-girl", "tempting-new-arrival", "charming-heartthrob", "strict-mentor", "corrupt-institution", "jealous-best-friend"],
  relationshipDynamics: ["enemies-to-lovers", "fake-marriage", "contract-relationship", "second-chance", "forbidden-affair", "boss-subordinate", "mentor-protege", "rivals-to-allies", "betrayer-victim", "family-obligation", "teammate-rivalry", "love-triangle", "couple-switching", "protector-protected", "captor-captive", "unlikely-allies", "rich-poor-romance", "competitive-dating"],
  conflictSetups: ["cheating-partner", "public-mistress-humiliation", "family-betrayal", "class-humiliation", "secret-pregnancy", "forced-marriage", "mistaken-identity", "hidden-identity", "inheritance-fight", "debt-pressure", "career-sabotage", "public-scandal", "ex-returns", "new-arrival-disruption", "romantic-rivalry", "competition-elimination", "wrongfully-accused", "powerful-family-opposes"],
  powerDynamics: ["female-power-rise", "male-lead-regret", "status-gap", "wealth-gap", "hidden-identity-power", "public-status-reversal", "social-rank-shifting", "public-selection", "boss-holds-power", "family-controls-fate", "rival-has-advantage", "outsider-gains-leverage", "protector-has-power", "power-swaps-midstory"],
  payoffTypes: ["public-humiliation", "secret-identity-reveal", "groveling-apology", "revenge-win", "rival-defeated", "romantic-claim", "chosen-at-recoupling", "rival-rejected", "public-romantic-claim", "status-reveal", "wealth-reveal", "family-acceptance", "villain-exposed", "dramatic-rescue", "proposal-or-commitment", "career-win", "competition-win"],
  pacingPromises: ["fast-hook", "payoff-by-episode-3", "payoff-by-episode-5", "no-slow-burn", "cliffhanger-heavy", "constant-reversals", "early-betrayal", "early-revenge", "quick-romantic-spark", "slow-burn", "mystery-box", "escalates-every-episode"],
  endingPromises: ["happy-ending", "bittersweet-ending", "no-forgiveness", "forgiveness-arc", "couple-endgame", "revenge-over-romance", "villain-punished", "status-restored", "family-reconciled", "open-ended", "tragic-ending"],
  activeAtoms: ["character-introduction", "personality-reveal", "relationship-seeding", "setting-establishment", "world-rules-introduction", "stakes-introduction", "first-impression", "status-quo-introduction", "love-triangle", "new-arrival-disruption", "jealousy", "rivalry-escalation", "betrayal", "secret-identity-reveal", "public-humiliation", "public-vindication", "groveling-apology", "revenge-win", "chosen-over-rival", "romantic-validation", "status-reveal", "wealth-reveal", "elimination-pressure", "partner-selection", "temptation", "social-strategy", "power-struggle", "female-power-rise", "male-lead-regret", "fast-revenge", "forbidden-desire", "dramatic-rescue"],
  emotionalBeats: ["orientation", "curiosity", "anticipation", "first-impression", "light-intrigue", "betrayal-reveal", "jealousy-spike", "public-vindication", "public-humiliation", "romantic-spark", "romantic-choice", "rivalry-escalation", "status-reversal", "secret-reveal", "revenge-payoff", "heartbreak", "temptation-test", "comic-relief", "danger-spike", "tearful-confession", "power-shift", "cliffhanger-shock"],
  narrativeRoles: ["hook", "setup", "inciting-incident", "escalation", "twist", "midseason-turn", "payoff", "cliffhanger", "reversal", "finale", "epilogue", "breather"],
  pacingTags: ["fast-hook", "payoff-episode", "cliffhanger-ending", "setup-heavy", "character-introduction", "world-building", "slow-build", "low-conflict", "twist-heavy", "constant-reversals", "slow-burn", "early-betrayal", "early-revenge", "quick-romantic-spark", "escalation"],
  setting: ["island", "villa", "school", "workplace", "court", "mansion", "city", "fantasy-world", "wartime", "fashion-world", "sports-arena", "luxury-world"],
  characterSystem: ["human-characters", "fruit-characters", "anthropomorphic-food"],
  worldType: ["real-world", "food-world", "fantasy-world", "alternate-history"],
  visualStyle: ["live-action", "ai-generated", "ai-stylized", "3d-animated", "glossy-toy-render", "pastel-candycore", "bright-resort", "romance-reality-style", "luxury-editorial", "fashion-campaign", "doll-like", "ornate-glamour", "cartoon-action", "exaggerated-expressions", "bright-outdoor", "cinematic-melodrama", "soap-opera", "luxury-interior", "warm-dramatic-lighting", "meme-captioned", "fashion-editorial", "sports-action", "reality-style", "meme-native", "cinematic", "bright", "moody", "glamorous", "glossy-character-render", "soft-realistic-lighting", "cartoon-3d", "dreamworks-inspired", "pixar-inspired", "glossy-render", "dark-luxury-interior", "neo-noir-lighting", "dark-romance-visuals", "anthropomorphic-fruit", "tropical-poolside", "dating-show-glam", "pastel-resort-glam", "candy-character-design", "domestic-interior", "domestic-melodrama", "luxury-corporate-interior", "corporate-romance-visuals", "storybook-melodrama", "theatrical-interior", "costume-forward", "warm-stage-lighting", "gothic-romance-interior", "cozy-cafe-interior", "rustic-warm-lighting", "workplace-ensemble-staging", "food-service-setting", "supernatural-thriller-visuals"],
  contentLineageType: ["original", "parody", "mashup", "fan-inspired", "licensed", "user-generated"],
  referenceSignals: ["wizard-fantasy", "prestige-crime", "luxury-fashion", "dating-reality", "sports-culture", "wartime-history"],
  episodeLengthBucket: ["under-thirty-sec", "thirty-to-sixty-sec", "one-to-three-min", "three-to-five-min", "over-five-min"],
  serialization: ["low", "medium", "high"],
  cliffhangerLevel: ["low", "medium", "high"],
  maturityRating: ["all", "teen", "mature"],
  language: ["en"],
  contentWarnings: []
};

const optionFields = Object.keys(defaultRecommendationOptions);
const showStatuses = new Set(["published", "hidden", "draft", "archived"]);

async function loadEnvFiles() {
  const candidates = [
    join(repoRoot, ".env.local"),
    join(repoRoot, "api/.env.local")
  ];

  for (const candidate of candidates) {
    try {
      const raw = await readFile(candidate, "utf8");
      raw.split(/\r?\n/).forEach((line) => {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) {
          return;
        }

        const separatorIndex = trimmed.indexOf("=");
        if (separatorIndex === -1) {
          return;
        }

        const key = trimmed.slice(0, separatorIndex).trim();
        const value = trimmed.slice(separatorIndex + 1).trim().replace(/^(['"`])([\s\S]*)\1$/, "$2");
        if (key && process.env[key] === undefined) {
          process.env[key] = value;
        }
      });
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
    }
  }
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  res.end(payload);
}

function sendRedirect(res, location) {
  res.writeHead(302, {
    location,
    "cache-control": "no-store"
  });
  res.end();
}

function sendError(res, status, message) {
  sendJson(res, status, { error: message });
}

async function readCatalog() {
  return JSON.parse(await readFile(catalogPath, "utf8"));
}

async function writeCatalog(catalog) {
  const tempPath = `${catalogPath}.tmp`;
  await writeFile(tempPath, `${JSON.stringify(catalog, null, 2)}\n`);
  await rename(tempPath, catalogPath);
}

async function readOptions() {
  try {
    return normalizeOptions(JSON.parse(await readFile(optionsPath, "utf8")));
  } catch (error) {
    if (error?.code === "ENOENT") {
      return structuredClone(defaultRecommendationOptions);
    }

    throw error;
  }
}

async function writeOptions(options) {
  const tempPath = `${optionsPath}.tmp`;
  await writeFile(tempPath, `${JSON.stringify(normalizeOptions(options), null, 2)}\n`);
  await rename(tempPath, optionsPath);
}

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return [...new Set(value.map(normalizeString).filter(Boolean))];
}

function normalizeShowStatus(value, fallback = "draft") {
  const status = normalizeString(value);
  return showStatuses.has(status) ? status : fallback;
}

function normalizeShowBasics(input, fallback) {
  const show = input && typeof input === "object" ? input : {};
  const title = normalizeString(show.title);
  const genre = normalizeString(show.genre);

  return {
    title: title || fallback.title,
    description: typeof show.description === "string" ? show.description.trim() : fallback.description,
    genre: genre || fallback.genre,
    status: normalizeShowStatus(show.status, fallback.status)
  };
}

function normalizeOptions(input) {
  const options = input && typeof input === "object" ? input : {};
  return Object.fromEntries(
    optionFields.map((field) => [
      field,
      normalizeStringArray(options[field] || defaultRecommendationOptions[field])
    ])
  );
}

function addOptions(target, field, values) {
  const existing = target[field] || [];
  target[field] = [...new Set([...existing, ...normalizeStringArray(values)])];
}

function mergeRecommendationIntoOptions(options, recommendation) {
  const nextOptions = normalizeOptions(options);

  addOptions(nextOptions, "primaryGenre", [recommendation.primaryGenre]);
  addOptions(nextOptions, "heroTraits", recommendation.heroTraits);
  addOptions(nextOptions, "secondaryGenres", recommendation.secondaryGenres);
  addOptions(nextOptions, "microGenres", recommendation.microGenres);
  addOptions(nextOptions, "storySignals", recommendation.storySignals);
  addOptions(nextOptions, "storyDrivers", recommendation.storyDrivers);
  addOptions(nextOptions, "tropes", recommendation.tropes);
  addOptions(nextOptions, "tone", recommendation.tone);
  addOptions(nextOptions, "emotionalFantasies", recommendation.emotionalFantasies);
  addOptions(nextOptions, "protagonistArchetypes", recommendation.protagonistArchetypes);
  addOptions(nextOptions, "counterpartArchetypes", recommendation.counterpartArchetypes);
  addOptions(nextOptions, "relationshipDynamics", recommendation.relationshipDynamics);
  addOptions(nextOptions, "conflictSetups", recommendation.conflictSetups);
  addOptions(nextOptions, "powerDynamics", recommendation.powerDynamics);
  addOptions(nextOptions, "payoffTypes", recommendation.payoffTypes);
  addOptions(nextOptions, "pacingPromises", recommendation.pacingPromises);
  addOptions(nextOptions, "endingPromises", recommendation.endingPromises);
  addOptions(nextOptions, "setting", recommendation.setting);
  addOptions(nextOptions, "characterSystem", recommendation.characterSystem);
  addOptions(nextOptions, "worldType", recommendation.worldType);
  addOptions(nextOptions, "visualStyle", recommendation.visualStyle);
  addOptions(nextOptions, "contentLineageType", [recommendation.contentLineage.type]);
  addOptions(nextOptions, "referenceSignals", recommendation.referenceSignals);
  addOptions(nextOptions, "episodeLengthBucket", [recommendation.format.episodeLengthBucket]);
  addOptions(nextOptions, "serialization", [recommendation.format.serialization]);
  addOptions(nextOptions, "cliffhangerLevel", [recommendation.format.cliffhangerLevel]);
  addOptions(nextOptions, "maturityRating", [recommendation.audience.maturityRating]);
  addOptions(nextOptions, "language", [recommendation.audience.language]);
  addOptions(nextOptions, "contentWarnings", recommendation.audience.contentWarnings);

  return nextOptions;
}

function mergeEpisodeRecommendationIntoOptions(options, recommendation) {
  const nextOptions = normalizeOptions(options);
  addOptions(nextOptions, "activeAtoms", recommendation.activeAtoms);
  addOptions(nextOptions, "emotionalBeats", [recommendation.emotionalBeat]);
  addOptions(nextOptions, "narrativeRoles", [recommendation.narrativeRole]);
  addOptions(nextOptions, "payoffTypes", recommendation.payoffTypes);
  addOptions(nextOptions, "pacingTags", recommendation.pacingTags);
  return nextOptions;
}

function normalizeNumber(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return fallback;
  }

  return Math.min(Math.max(number, min), max);
}

function normalizeQualityLabel(value, score) {
  const fallbackScore = normalizeNumber(score, 0.7, 0, 1);
  const fallbackLabel = Math.round(fallbackScore * 4 + 1);
  return Math.round(normalizeNumber(value, fallbackLabel, 1, 5));
}

function base64Url(input) {
  return Buffer.from(input).toString("base64url");
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

async function buildPlaybackTicket(episode) {
  if (episode.provider !== "cloudflare_stream" || !episode.providerAssetId) {
    const error = new Error(`Unsupported playback provider for episode ${episode.id}`);
    error.statusCode = 400;
    throw error;
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

function normalizeRecommendation(input) {
  const recommendation = input && typeof input === "object" ? input : {};
  const format = recommendation.format && typeof recommendation.format === "object" ? recommendation.format : {};
  const audience = recommendation.audience && typeof recommendation.audience === "object" ? recommendation.audience : {};
  const release = recommendation.release && typeof recommendation.release === "object" ? recommendation.release : {};
  const editorial = recommendation.editorial && typeof recommendation.editorial === "object" ? recommendation.editorial : {};
  const contentLineage = recommendation.contentLineage && typeof recommendation.contentLineage === "object"
    ? recommendation.contentLineage
    : {};

  return {
    primaryGenre: normalizeString(recommendation.primaryGenre),
    heroTraits: normalizeStringArray(recommendation.heroTraits),
    secondaryGenres: normalizeStringArray(recommendation.secondaryGenres),
    microGenres: normalizeStringArray(recommendation.microGenres),
    storySignals: normalizeStringArray(recommendation.storySignals),
    storyDrivers: normalizeStringArray(recommendation.storyDrivers),
    tropes: normalizeStringArray(recommendation.tropes),
    tone: normalizeStringArray(recommendation.tone),
    emotionalFantasies: normalizeStringArray(recommendation.emotionalFantasies),
    protagonistArchetypes: normalizeStringArray(recommendation.protagonistArchetypes),
    counterpartArchetypes: normalizeStringArray(recommendation.counterpartArchetypes),
    relationshipDynamics: normalizeStringArray(recommendation.relationshipDynamics),
    conflictSetups: normalizeStringArray(recommendation.conflictSetups),
    powerDynamics: normalizeStringArray(recommendation.powerDynamics),
    payoffTypes: normalizeStringArray(recommendation.payoffTypes),
    pacingPromises: normalizeStringArray(recommendation.pacingPromises),
    endingPromises: normalizeStringArray(recommendation.endingPromises),
    setting: normalizeStringArray(recommendation.setting),
    characterSystem: normalizeStringArray(recommendation.characterSystem),
    worldType: normalizeStringArray(recommendation.worldType),
    visualStyle: normalizeStringArray(recommendation.visualStyle),
    contentLineage: {
      type: normalizeString(contentLineage.type)
    },
    referenceSignals: normalizeStringArray(recommendation.referenceSignals),
    format: {
      episodeLengthBucket: normalizeString(format.episodeLengthBucket),
      serialization: normalizeString(format.serialization),
      cliffhangerLevel: normalizeString(format.cliffhangerLevel),
      freePreviewEpisodes: normalizeNumber(format.freePreviewEpisodes, 0, 0, 999)
    },
    audience: {
      maturityRating: normalizeString(audience.maturityRating),
      language: normalizeString(audience.language) || "en",
      contentWarnings: normalizeStringArray(audience.contentWarnings)
    },
    release: {
      publishedAt: normalizeString(release.publishedAt),
      freshnessWindowDays: normalizeNumber(release.freshnessWindowDays, 14, 0, 3650)
    },
    editorial: {
      qualityLabel: normalizeQualityLabel(editorial.qualityLabel, editorial.qualityScore),
      qualityScore: normalizeNumber(editorial.qualityScore, 0.7, 0, 1),
      coldStartPriority: Math.round(normalizeNumber(editorial.coldStartPriority, 5, 0, 10)),
      featuredBoost: normalizeNumber(editorial.featuredBoost, 1, 0, 5)
    },
    similarShowIds: normalizeStringArray(recommendation.similarShowIds)
  };
}

function normalizeEpisodeRecommendation(input) {
  const recommendation = input && typeof input === "object" ? input : {};
  return {
    scriptNotes: normalizeString(recommendation.scriptNotes),
    activeAtoms: normalizeStringArray(recommendation.activeAtoms),
    emotionalBeat: normalizeString(recommendation.emotionalBeat),
    narrativeRole: normalizeString(recommendation.narrativeRole),
    payoffTypes: normalizeStringArray(recommendation.payoffTypes),
    pacingTags: normalizeStringArray(recommendation.pacingTags)
  };
}

function deriveShowStats(catalog, showId) {
  const episodes = catalog.episodes.filter((episode) => episode.showId === showId && episode.status === "published");
  const durationTotal = episodes.reduce((sum, episode) => sum + Number(episode.durationSeconds || 0), 0);
  const firstPublishedAt = episodes
    .map((episode) => episode.publishedAt)
    .filter(Boolean)
    .sort()[0] || "";

  return {
    episodeCount: episodes.length,
    avgEpisodeSeconds: episodes.length ? Math.round(durationTotal / episodes.length) : 0,
    freePreviewEpisodes: episodes.filter((episode) => episode.isFreePreview).length,
    lockedEpisodes: episodes.filter((episode) => episode.isLocked).length,
    firstPublishedAt
  };
}

function publicShows(catalog) {
  return catalog.shows
    .slice()
    .sort((a, b) => Number(a.sortOrder || 0) - Number(b.sortOrder || 0))
    .map((show) => {
      const stats = deriveShowStats(catalog, show.id);
      return {
        id: show.id,
        title: show.title,
        description: show.description,
        genre: show.genre,
        posterUrl: `/api/shows/${show.id}/poster`,
        coverUrl: `/api/shows/${show.id}/cover`,
        status: show.status,
        sortOrder: show.sortOrder,
        stats,
        recommendation: {
          ...structuredClone(emptyRecommendation),
          ...show.recommendation,
          format: {
            ...emptyRecommendation.format,
            avgEpisodeSeconds: stats.avgEpisodeSeconds,
            freePreviewEpisodes: stats.freePreviewEpisodes,
            ...show.recommendation?.format
          },
          audience: {
            ...emptyRecommendation.audience,
            ...show.recommendation?.audience
          },
          release: {
            ...emptyRecommendation.release,
            publishedAt: stats.firstPublishedAt,
            ...show.recommendation?.release
          },
          editorial: {
            ...emptyRecommendation.editorial,
            ...show.recommendation?.editorial
          },
          contentLineage: {
            ...emptyRecommendation.contentLineage,
            ...show.recommendation?.contentLineage
          },
          characterSystem: show.recommendation?.characterSystem || [],
          worldType: show.recommendation?.worldType || []
        }
      };
    });
}

function publicEpisodes(catalog, showId) {
  return catalog.episodes
    .filter((episode) => episode.showId === showId)
    .slice()
    .sort((a, b) => Number(a.episodeNumber || 0) - Number(b.episodeNumber || 0))
    .map((episode) => ({
      id: episode.id,
      showId: episode.showId,
      episodeNumber: episode.episodeNumber,
      title: episode.title,
      description: episode.description,
      durationSeconds: episode.durationSeconds,
      provider: episode.provider,
      providerAssetId: episode.providerAssetId,
      thumbnailUrl: `/api/episodes/${episode.id}/thumbnail`,
      playbackPath: `/api/episodes/${episode.id}/playback`,
      isLocked: episode.isLocked,
      isFreePreview: episode.isFreePreview,
      status: episode.status,
      publishedAt: episode.publishedAt,
      recommendation: {
        ...structuredClone(emptyEpisodeRecommendation),
        ...episode.recommendation
      }
    }));
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }

  return Buffer.concat(chunks).toString("utf8");
}

async function handleApi(req, res, url) {
  if (req.method === "GET" && url.pathname === "/api/shows") {
    const catalog = await readCatalog();
    sendJson(res, 200, { shows: publicShows(catalog) });
    return true;
  }

  const showEpisodesMatch = url.pathname.match(/^\/api\/shows\/([^/]+)\/episodes$/);
  if (req.method === "GET" && showEpisodesMatch) {
    const showId = decodeURIComponent(showEpisodesMatch[1]);
    const catalog = await readCatalog();
    if (!catalog.shows.some((show) => show.id === showId)) {
      sendError(res, 404, "show_not_found");
      return true;
    }

    sendJson(res, 200, { episodes: publicEpisodes(catalog, showId) });
    return true;
  }

  if (req.method === "GET" && url.pathname === "/api/options") {
    sendJson(res, 200, { options: await readOptions() });
    return true;
  }

  if (req.method === "PUT" && url.pathname === "/api/options") {
    let body;
    try {
      body = JSON.parse(await readRequestBody(req));
    } catch {
      sendError(res, 400, "invalid_json");
      return true;
    }

    const options = normalizeOptions(body.options);
    await writeOptions(options);
    sendJson(res, 200, { options });
    return true;
  }

  const recommendationMatch = url.pathname.match(/^\/api\/shows\/([^/]+)\/recommendation$/);
  if (req.method === "PUT" && recommendationMatch) {
    const showId = decodeURIComponent(recommendationMatch[1]);
    const catalog = await readCatalog();
    const show = catalog.shows.find((candidate) => candidate.id === showId);
    if (!show) {
      sendError(res, 404, "show_not_found");
      return true;
    }

    let body;
    try {
      body = JSON.parse(await readRequestBody(req));
    } catch {
      sendError(res, 400, "invalid_json");
      return true;
    }

    const recommendation = normalizeRecommendation(body.recommendation);
    const showBasics = normalizeShowBasics(body.show, show);
    show.title = showBasics.title;
    show.description = showBasics.description;
    show.genre = showBasics.genre;
    show.status = showBasics.status;
    show.recommendation = recommendation;
    await writeCatalog(catalog);
    const options = mergeRecommendationIntoOptions(await readOptions(), recommendation);
    await writeOptions(options);
    sendJson(res, 200, {
      show: publicShows(catalog).find((candidate) => candidate.id === showId),
      options
    });
    return true;
  }

  const episodeRecommendationMatch = url.pathname.match(/^\/api\/episodes\/([^/]+)\/recommendation$/);
  if (req.method === "PUT" && episodeRecommendationMatch) {
    const episodeId = decodeURIComponent(episodeRecommendationMatch[1]);
    const catalog = await readCatalog();
    const episode = catalog.episodes.find((candidate) => candidate.id === episodeId);
    if (!episode) {
      sendError(res, 404, "episode_not_found");
      return true;
    }

    let body;
    try {
      body = JSON.parse(await readRequestBody(req));
    } catch {
      sendError(res, 400, "invalid_json");
      return true;
    }

    const recommendation = normalizeEpisodeRecommendation(body.recommendation);
    episode.recommendation = recommendation;
    await writeCatalog(catalog);
    const options = mergeEpisodeRecommendationIntoOptions(await readOptions(), recommendation);
    await writeOptions(options);
    sendJson(res, 200, {
      episode: publicEpisodes(catalog, episode.showId).find((candidate) => candidate.id === episodeId),
      options
    });
    return true;
  }

  const showPosterMatch = url.pathname.match(/^\/api\/shows\/([^/]+)\/poster$/);
  if (req.method === "GET" && showPosterMatch) {
    const showId = decodeURIComponent(showPosterMatch[1]);
    const catalog = await readCatalog();
    const show = catalog.shows.find((candidate) => candidate.id === showId);
    if (!show) {
      sendError(res, 404, "show_not_found");
      return true;
    }

    const ticket = await buildThumbnailTicket({ posterUrl: show.posterUrl });
    sendRedirect(res, ticket.url);
    return true;
  }

  const showCoverMatch = url.pathname.match(/^\/api\/shows\/([^/]+)\/cover$/);
  if (req.method === "GET" && showCoverMatch) {
    const showId = decodeURIComponent(showCoverMatch[1]);
    const catalog = await readCatalog();
    const show = catalog.shows.find((candidate) => candidate.id === showId);
    if (!show) {
      sendError(res, 404, "show_not_found");
      return true;
    }

    const ticket = await buildThumbnailTicket({ coverUrl: show.coverUrl });
    sendRedirect(res, ticket.url);
    return true;
  }

  const episodeThumbnailMatch = url.pathname.match(/^\/api\/episodes\/([^/]+)\/thumbnail$/);
  if (req.method === "GET" && episodeThumbnailMatch) {
    const episodeId = decodeURIComponent(episodeThumbnailMatch[1]);
    const catalog = await readCatalog();
    const episode = catalog.episodes.find((candidate) => candidate.id === episodeId);
    if (!episode) {
      sendError(res, 404, "episode_not_found");
      return true;
    }

    const ticket = await buildThumbnailTicket(episode);
    sendRedirect(res, ticket.url);
    return true;
  }

  const episodePlaybackMatch = url.pathname.match(/^\/api\/episodes\/([^/]+)\/playback$/);
  if (req.method === "GET" && episodePlaybackMatch) {
    const episodeId = decodeURIComponent(episodePlaybackMatch[1]);
    const catalog = await readCatalog();
    const episode = catalog.episodes.find((candidate) => candidate.id === episodeId);
    if (!episode) {
      sendError(res, 404, "episode_not_found");
      return true;
    }

    const ticket = await buildPlaybackTicket(episode);
    sendJson(res, 200, ticket);
    return true;
  }

  return false;
}

async function serveStatic(res, pathname) {
  const relativePath = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  const filePath = join(publicDir, relativePath);
  const resolvedPath = resolve(filePath);

  if (!resolvedPath.startsWith(publicDir) || !existsSync(resolvedPath)) {
    sendError(res, 404, "not_found");
    return;
  }

  const contentType = mimeTypes[extname(resolvedPath)] || "application/octet-stream";
  res.writeHead(200, {
    "content-type": contentType,
    "cache-control": "no-store"
  });
  res.end(await readFile(resolvedPath));
}

await loadEnvFiles();

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    if (url.pathname.startsWith("/api/") && await handleApi(req, res, url)) {
      return;
    }

    await serveStatic(res, url.pathname);
  } catch (error) {
    console.error(error);
    sendError(res, 500, "internal_server_error");
  }
}).listen(port, host, () => {
  console.log(`Recommendation admin running at http://${host}:${port}`);
});
