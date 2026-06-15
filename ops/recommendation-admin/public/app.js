const explanations = {
  title: "Public show title used in the app, sidebar, and show info tray.",
  description: "Public synopsis shown in the app. Keep this audience-facing; do not paste internal script notes here.",
  genre: "Short public genre label shown in the app.",
  status: "Catalog visibility state for this show.",
  primaryGenre: "Coarse first-pass similarity signal.",
  heroTraits: "Short user-facing traits shown under the home hero title. Keep these broad, punchy, and limited to about four.",
  secondaryGenres: "Format and flavor adjacencies, not a repeat of primary genre.",
  microGenres: "Shelf-ready categories such as dating-competition or billionaire-romance.",
  storySignals: "High-signal show-wide taste tags that cut across genre, trope, and story engine.",
  storyDrivers: "Plot engines such as partner-selection, elimination-pressure, or status-climbing.",
  tropes: "Repeatable story mechanics that drive taste similarity.",
  tone: "Mood matching for short-form recommendations.",
  emotionalFantasies: "The emotional craving the story satisfies.",
  protagonistArchetypes: "Who the viewer identifies with or roots for.",
  counterpartArchetypes: "The key other force: love interest, rival, villain, boss, mentor, or institution.",
  relationshipDynamics: "The interpersonal engine between protagonist and counterpart.",
  conflictSetups: "The wound, problem, or premise that starts the craving loop.",
  powerDynamics: "Who has leverage and how that leverage shifts.",
  payoffTypes: "The specific moments viewers are waiting to see.",
  pacingPromises: "How quickly the show promises payoff and reversal.",
  endingPromises: "The emotional contract for where the story lands.",
  setting: "Where the story takes place.",
  characterSystem: "Reusable character ontology, such as fruit-characters or human-characters.",
  worldType: "The world logic, such as food-world, real-world, or fantasy-world.",
  visualStyle: "How the show looks and feels in the feed.",
  contentLineage: "Separates original content from parody, mashup, and fan-inspired shows.",
  referenceSignals: "Abstract recognition signals for parody or mashup shows.",
  format: "Length and structure shape completion and binge behavior.",
  audience: "Eligibility, language, and safety filters.",
  release: "Freshness controls for rows and cold-start rotation.",
  editorial: "Manual ranking controls while the catalog is small.",
  qualityLabel: "Manual 1-5 quality label for quick editorial screening. Higher numbers are better.",
  similarShowIds: "Direct override for small catalog recommendations."
};

const optionLabels = {
  heroTraits: "Hero traits",
  primaryGenre: "Primary genre",
  secondaryGenres: "Secondary genres",
  microGenres: "Micro genres",
  storySignals: "Story signals",
  storyDrivers: "Story drivers",
  tropes: "Tropes",
  tone: "Tone",
  emotionalFantasies: "Emotional fantasies",
  protagonistArchetypes: "Protagonist archetypes",
  counterpartArchetypes: "Counterpart archetypes",
  relationshipDynamics: "Relationship dynamics",
  conflictSetups: "Conflict setups",
  powerDynamics: "Power dynamics",
  payoffTypes: "Payoff types",
  pacingPromises: "Pacing promises",
  endingPromises: "Ending promises",
  setting: "Setting",
  characterSystem: "Character system",
  worldType: "World type",
  visualStyle: "Visual style",
  contentLineageType: "Content lineage",
  referenceSignals: "Reference signals",
  episodeLengthBucket: "Episode length bucket",
  serialization: "Serialization",
  cliffhangerLevel: "Cliffhanger level",
  maturityRating: "Maturity rating",
  language: "Language",
  contentWarnings: "Content warnings",
  activeAtoms: "Episode active atoms",
  emotionalBeats: "Episode emotional beats",
  narrativeRoles: "Episode narrative roles",
  pacingTags: "Episode pacing tags"
};

const visibleOptionFields = [
  "heroTraits",
  "primaryGenre",
  "microGenres",
  "storySignals",
  "emotionalFantasies",
  "protagonistArchetypes",
  "counterpartArchetypes",
  "relationshipDynamics",
  "conflictSetups",
  "powerDynamics",
  "payoffTypes",
  "pacingPromises",
  "endingPromises",
  "characterSystem",
  "worldType",
  "tone",
  "visualStyle",
  "contentLineageType",
  "activeAtoms",
  "emotionalBeats",
  "narrativeRoles",
  "pacingTags"
];

const optionBuckets = {
  storySignals: {
    "Billionaire / Luxury Romance": [
      "billionaire-lover",
      "wealth-gap",
      "luxury-life",
      "power-imbalance",
      "business-rescue",
      "forced-proximity"
    ],
    "Second-Chance / Recognition": [
      "one-night-stand",
      "morning-after-shock",
      "anonymous-connection",
      "lost-connection-reunion",
      "recognition-hook",
      "he-never-forgot-her",
      "keepsake-token",
      "protective-distance"
    ],
    "Emotional Wounds / Growth": [
      "heartbreak",
      "fish-out-of-water",
      "personal-transformation",
      "secret-keeping",
      "mystery-reveal",
      "romantic-pursuit"
    ],
    "Dating Game": [
      "dating-game",
      "partner-selection",
      "recoupling",
      "public-vote",
      "elimination-pressure",
      "confessional-interviews",
      "new-arrival-disruption",
      "love-triangle",
      "couple-switching",
      "jealousy-spiral",
      "viewer-choice"
    ],
    "Marital Betrayal / Revenge": [
      "betrayed-wife",
      "cheating-husband",
      "mistress-takedown",
      "financial-exploitation",
      "hidden-knowledge-advantage",
      "evidence-gathering",
      "revenge-trap",
      "glow-up-transformation",
      "wife-secretly-knows",
      "villain-thinks-he-is-safe"
    ],
    "Parody / Remix": [
      "parody-recognition",
      "fashion-remix",
      "prestige-show-remix",
      "wizard-fantasy-remix"
    ],
    "Sports / Action / History": [
      "sports-underdog",
      "training-grind",
      "team-competition",
      "war-fantasy",
      "alternate-history"
    ],
    "New / Uncategorized": []
  },
  microGenres: {
    "Dating / Reality": [
      "dating-competition",
      "dating-show",
      "reality-competition",
      "villa-romance"
    ],
    "Romance / Class": [
      "billionaire-romance",
      "class-gap-romance"
    ],
    "Revenge / Betrayal": [
      "betrayed-wife",
      "cheating-husband",
      "mistress-takedown",
      "financial-betrayal",
      "revenge",
      "glow-up"
    ],
    "Comedy / Parody": [
      "fashion-satire",
      "fantasy-parody",
      "crime-parody"
    ],
    "Genre Worlds": [
      "sports-underdog",
      "alternate-history",
      "war-fantasy"
    ],
    "New / Uncategorized": []
  },
  emotionalFantasies: {
    "Revenge & Vindication": [
      "revenge-glow-up",
      "public-vindication",
      "justice-served",
      "humiliation-reversal",
      "betrayed-wife",
      "revenge",
      "exploited-woman-takes-control",
      "mistress-humiliation"
    ],
    "Romance & Desire": [
      "chosen-over-rival",
      "romantic-validation",
      "forbidden-desire",
      "dangerous-desire",
      "second-chance-healing"
    ],
    "Status & Luxury": [
      "status-transformation",
      "luxury-escape",
      "beautiful-life-upgrade",
      "recognition-and-fame"
    ],
    "Power & Protection": [
      "power-fantasy",
      "social-domination",
      "secret-power-reveal",
      "being-protected"
    ],
    "Family & Survival": [
      "family-restoration",
      "survival-against-odds",
      "underdog-triumph"
    ],
    "New / Uncategorized": []
  },
  protagonistArchetypes: {
    "Romantic Leads": [
      "strong-heroine",
      "flirty-contestant",
      "romantic-underdog",
      "single-parent"
    ],
    "Underdogs & Outsiders": [
      "naive-outsider",
      "ambitious-underdog",
      "bullied-outcast",
      "comic-underdog",
      "gifted-rookie",
      "ordinary-person-chosen"
    ],
    "Hidden Status": [
      "hidden-heir",
      "hidden-heiress",
      "fallen-heiress",
      "disgraced-star",
      "rebellious-princess"
    ],
    "Survivors & Schemer Types": [
      "betrayed-spouse",
      "strategic-revenge-heroine",
      "glow-up-heroine",
      "survivor",
      "schemer",
      "reluctant-hero"
    ],
    "New / Uncategorized": []
  },
  counterpartArchetypes: {
    "Love Interests": [
      "cold-billionaire",
      "protective-alpha",
      "toxic-heartthrob",
      "secretly-soft-ceo",
      "charming-heartthrob",
      "tempting-new-arrival"
    ],
    "Exes & Rivals": [
      "regretful-ex",
      "arrogant-rival",
      "public-mistress",
      "cheating-husband",
      "gold-digging-mistress",
      "financial-abuser",
      "smug-side-piece",
      "elite-mean-girl",
      "jealous-best-friend"
    ],
    "Authority Figures": [
      "demanding-coach",
      "strict-mentor",
      "crime-boss"
    ],
    "Villains & Institutions": [
      "villainous-family",
      "dark-lord",
      "corrupt-institution"
    ],
    "New / Uncategorized": []
  },
  relationshipDynamics: {
    "Romance Premises": [
      "enemies-to-lovers",
      "fake-marriage",
      "contract-relationship",
      "second-chance",
      "forbidden-affair",
      "rich-poor-romance"
    ],
    "Dating Competition": [
      "love-triangle",
      "couple-switching",
      "competitive-dating"
    ],
    "Power & Work": [
      "boss-subordinate",
      "mentor-protege",
      "protector-protected",
      "captor-captive"
    ],
    "Rivalry & Betrayal": [
      "rivals-to-allies",
      "betrayer-victim",
      "marital-betrayal",
      "husband-mistress-affair",
      "wife-secretly-knows",
      "mistress-vs-wife",
      "teammate-rivalry",
      "unlikely-allies"
    ],
    "Family / Obligation": [
      "family-obligation"
    ],
    "New / Uncategorized": []
  },
  conflictSetups: {
    "Betrayal & Humiliation": [
      "cheating-partner",
      "public-mistress-humiliation",
      "affair-discovery",
      "stolen-marital-assets",
      "heirloom-violation",
      "family-betrayal",
      "class-humiliation",
      "public-scandal",
      "wrongfully-accused"
    ],
    "Secrets & Identity": [
      "secret-pregnancy",
      "mistaken-identity",
      "hidden-identity",
      "ex-returns"
    ],
    "Money / Class / Family Control": [
      "forced-marriage",
      "inheritance-fight",
      "debt-pressure",
      "secret-debt",
      "powerful-family-opposes"
    ],
    "Romance Competition": [
      "new-arrival-disruption",
      "romantic-rivalry",
      "competition-elimination"
    ],
    "Career / Public Life": [
      "career-sabotage"
    ],
    "New / Uncategorized": []
  },
  powerDynamics: {
    "Status & Wealth Gaps": [
      "status-gap",
      "wealth-gap",
      "public-status-reversal",
      "social-rank-shifting"
    ],
    "Hidden / Reversed Power": [
      "hidden-identity-power",
      "outsider-gains-leverage",
      "power-swaps-midstory",
      "hidden-knowledge-advantage",
      "wife-gains-leverage",
      "villain-thinks-he-is-safe",
      "mistress-overplays-hand"
    ],
    "Romance Power": [
      "female-power-rise",
      "male-lead-regret",
      "protector-has-power"
    ],
    "Institutional Power": [
      "boss-holds-power",
      "family-controls-fate",
      "rival-has-advantage"
    ],
    "Game / Public Choice": [
      "public-selection"
    ],
    "New / Uncategorized": []
  },
  pacingPromises: {
    "Fast Start": [
      "fast-hook",
      "early-betrayal",
      "early-revenge",
      "quick-romantic-spark"
    ],
    "Payoff Timing": [
      "payoff-by-episode-3",
      "payoff-by-episode-5",
      "no-slow-burn"
    ],
    "Twists & Momentum": [
      "cliffhanger-heavy",
      "constant-reversals",
      "mystery-box",
      "escalates-every-episode"
    ],
    "Slow Build": [
      "slow-burn"
    ],
    "New / Uncategorized": []
  },
  endingPromises: {
    "Romance Endings": [
      "happy-ending",
      "couple-endgame",
      "forgiveness-arc",
      "revenge-over-romance"
    ],
    "Justice / Status Endings": [
      "villain-punished",
      "status-restored",
      "family-reconciled",
      "no-forgiveness"
    ],
    "Open / Dark Endings": [
      "bittersweet-ending",
      "open-ended",
      "tragic-ending"
    ],
    "New / Uncategorized": []
  },
  activeAtoms: {
    "Dating Competition": [
      "partner-selection",
      "new-arrival-disruption",
      "public-vote",
      "forced-pairing",
      "cliffhanger-pairing",
      "elimination-pressure",
      "social-strategy",
      "love-triangle",
      "jealousy",
      "rivalry-escalation",
      "romantic-spark",
      "romantic-claim",
      "chosen-over-rival",
      "physical-confrontation"
    ],
    "Billionaire Romance / Second-Chance": [
      "one-night-stand",
      "morning-after-shock",
      "anonymous-connection",
      "keepsake-gift",
      "reencounter-setup",
      "reencounter-reveal",
      "he-never-forgot-her",
      "wealth-reveal",
      "status-reveal",
      "power-imbalance",
      "forced-proximity",
      "romantic-validation",
      "mutual-longing",
      "anonymous-caregiving",
      "life-hardship",
      "class-humiliation"
    ],
    "Mistress Revenge / Betrayed Wife": [
      "lying",
      "financial-exploitation",
      "mistress-provocation",
      "mistress-entitlement",
      "affair-evidence-planted",
      "betrayal-discovery",
      "evidence-discovery",
      "hidden-knowledge-advantage",
      "covert-investigation",
      "revenge-vow",
      "trap-setting",
      "controlled-confrontation-setup",
      "cover-story-backfire",
      "glow-up-transformation",
      "self-reinvention",
      "self-sacrifice"
    ],
    "Universal Setup": [
      "character-introduction",
      "personality-reveal",
      "relationship-seeding",
      "setting-establishment",
      "world-rules-introduction",
      "stakes-introduction",
      "first-impression",
      "status-quo-introduction"
    ],
    "Universal Romance / Desire": [
      "crush-reveal",
      "romantic-spark",
      "romantic-validation",
      "romantic-pursuit",
      "forbidden-desire",
      "temptation",
      "love-chain",
      "unrequited-crush",
      "love-triangle",
      "chosen-over-rival"
    ],
    "Universal Conflict / Emotion": [
      "jealousy",
      "rivalry-escalation",
      "betrayal",
      "power-struggle",
      "heartbreak",
      "tearful-confession",
      "friend-warning",
      "physical-confrontation"
    ],
    "Universal Reveal / Exposure": [
      "secret-reveal",
      "secret-identity-reveal",
      "cliffhanger-exposure",
      "public-humiliation",
      "public-vindication",
      "status-reveal",
      "wealth-reveal"
    ],
    "Universal Consequence / Transformation": [
      "pregnancy-discovery",
      "pregnancy-loss",
      "life-hardship",
      "self-sacrifice",
      "self-reinvention",
      "glow-up-transformation",
      "class-humiliation"
    ],
    "Universal Power / Payoff": [
      "female-power-rise",
      "male-lead-regret",
      "groveling-apology",
      "fast-revenge",
      "revenge-win",
      "dramatic-rescue"
    ],
    "New / Uncategorized": []
  },
  emotionalBeats: {
    "Setup Feelings": ["orientation", "curiosity", "anticipation", "first-impression", "light-intrigue"],
    "Romance": ["romantic-spark", "romantic-choice", "romantic-tension", "temptation-test", "romantic-validation"],
    "Conflict": ["jealousy-spike", "rivalry-escalation", "heartbreak", "tearful-confession", "betrayal-reveal", "betrayal-discovery"],
    "Reveal & Payoff": ["secret-reveal", "public-vindication", "public-humiliation", "status-reversal", "revenge-payoff", "power-shift"],
    "Shock / Danger / Comedy": ["cliffhanger-shock", "danger-spike", "comic-relief"],
    "New / Uncategorized": []
  },
  payoffTypes: {
    "Dating Game Reveals": ["chosen-at-recoupling", "date-choice-reveal", "rival-rejected", "romantic-claim", "public-romantic-claim"],
    "Exposure & Justice": ["public-humiliation", "secret-identity-reveal", "hidden-agenda-reveal", "villain-exposed", "revenge-win", "rival-defeated", "affair-confirmation", "evidence-confirmation", "mistress-takedown", "cheating-husband-punished"],
    "Status & Achievement": ["status-reveal", "wealth-reveal", "career-win", "competition-win", "asset-recovery"],
    "Recognition / Reunion": ["reencounter-reveal", "romantic-validation", "he-never-forgot-her"],
    "Transformation": ["glow-up-transformation"],
    "Romance / Family": ["groveling-apology", "proposal-or-commitment", "family-acceptance"],
    "Action": ["dramatic-rescue"],
    "New / Uncategorized": []
  },
  pacingTags: {
    "Setup / Slow Build": ["setup-heavy", "character-introduction", "world-building", "slow-build", "slow-burn", "low-conflict"],
    "Fast Hook / Spark": ["fast-hook", "quick-romantic-spark", "early-betrayal", "early-revenge"],
    "Twists & Cliffhangers": ["cliffhanger-ending", "twist-heavy", "constant-reversals", "escalation"],
    "Payoff": ["payoff-episode"],
    "New / Uncategorized": []
  },
  narrativeRoles: {
    "Beginning": ["hook", "setup", "inciting-incident"],
    "Middle Movement": ["escalation", "twist", "reversal", "midseason-turn"],
    "Payoff / Ending": ["payoff", "cliffhanger", "finale", "epilogue"],
    "Reset / Breath": ["breather"],
    "New / Uncategorized": []
  }
};

const episodeAtomStoryPalettes = {
  "Dating Competition": [
    "partner-selection",
    "new-arrival-disruption",
    "public-vote",
    "forced-pairing",
    "cliffhanger-pairing",
    "elimination-pressure",
    "love-triangle",
    "jealousy",
    "rivalry-escalation",
    "romantic-spark",
    "chosen-over-rival",
    "physical-confrontation"
  ],
  "Billionaire Romance / Second-Chance": [
    "one-night-stand",
    "morning-after-shock",
    "relationship-seeding",
    "romantic-spark",
    "anonymous-connection",
    "keepsake-gift",
    "reencounter-setup",
    "reencounter-reveal",
    "he-never-forgot-her",
    "wealth-reveal",
    "status-reveal",
    "power-imbalance",
    "forced-proximity",
    "romantic-validation",
    "mutual-longing",
    "anonymous-caregiving",
    "life-hardship",
    "class-humiliation"
  ],
  "Mistress Revenge / Betrayed Wife": [
    "lying",
    "betrayal",
    "heartbreak",
    "financial-exploitation",
    "mistress-provocation",
    "mistress-entitlement",
    "affair-evidence-planted",
    "betrayal-discovery",
    "evidence-discovery",
    "hidden-knowledge-advantage",
    "covert-investigation",
    "revenge-vow",
    "trap-setting",
    "controlled-confrontation-setup",
    "cover-story-backfire",
    "glow-up-transformation",
    "self-reinvention",
    "self-sacrifice",
    "female-power-rise"
  ]
};

const episodeAtomStorySignals = {
  "Dating Competition": [
    "dating-game",
    "partner-selection",
    "recoupling",
    "public-vote",
    "elimination-pressure",
    "confessional-interviews",
    "new-arrival-disruption",
    "love-triangle",
    "couple-switching",
    "jealousy-spiral",
    "viewer-choice",
    "dating-competition",
    "dating-show",
    "reality-competition",
    "villa-romance"
  ],
  "Billionaire Romance / Second-Chance": [
    "billionaire-lover",
    "power-imbalance",
    "luxury-life",
    "fish-out-of-water",
    "wealth-gap",
    "recognition-hook",
    "one-night-stand",
    "morning-after-shock",
    "anonymous-connection",
    "keepsake-token",
    "he-never-forgot-her",
    "forced-proximity",
    "protective-distance",
    "business-rescue",
    "lost-connection-reunion",
    "billionaire-romance",
    "class-gap-romance"
  ],
  "Mistress Revenge / Betrayed Wife": [
    "betrayed-wife",
    "cheating-husband",
    "mistress-takedown",
    "financial-exploitation",
    "hidden-knowledge-advantage",
    "evidence-gathering",
    "revenge-trap",
    "glow-up-transformation",
    "wife-secretly-knows",
    "villain-thinks-he-is-safe",
    "financial-betrayal",
    "revenge",
    "glow-up"
  ]
};

let shows = [];
let episodesByShowId = {};
let options = {};
let selectedShowId = "";
let selectedEpisodeId = "";
let dirty = false;
let episodeDirty = false;
let optionsDirty = false;
let selectedOptionField = "microGenres";
const playbackSessions = new Map();

const showList = document.querySelector("#showList");
const showHeader = document.querySelector("#showHeader");
const episodeTagger = document.querySelector("#episodeTagger");
const form = document.querySelector("#recommendationForm");
const optionBank = document.querySelector("#optionBank");
const searchInput = document.querySelector("#searchInput");
const statusFilterSelect = document.querySelector("#statusFilterSelect");
const showButtonTemplate = document.querySelector("#showButtonTemplate");
const allStatusesFilterValue = "all";
const showStatusOptions = [
  { value: "published", label: "Published" },
  { value: "hidden", label: "Hidden" },
  { value: "draft", label: "Draft" },
  { value: "archived", label: "Archived" }
];

function getSelectedShow() {
  return shows.find((show) => show.id === selectedShowId);
}

function getSelectedEpisodes() {
  return episodesByShowId[selectedShowId] || [];
}

function getSelectedEpisode() {
  return getSelectedEpisodes().find((episode) => episode.id === selectedEpisodeId);
}

function getPath(source, path) {
  return path.split(".").reduce((value, key) => value?.[key], source);
}

function setPath(target, path, value) {
  const keys = path.split(".");
  let cursor = target;
  keys.slice(0, -1).forEach((key) => {
    cursor[key] = cursor[key] || {};
    cursor = cursor[key];
  });
  cursor[keys.at(-1)] = value;
}

function recommendationValue(path) {
  return getPath(getSelectedShow()?.recommendation, path) ?? "";
}

function recommendationArray(path) {
  const value = recommendationValue(path);
  return Array.isArray(value) ? value : [];
}

function setRecommendationValue(path, value) {
  setPath(getSelectedShow().recommendation, path, value);
  setDirty(true);
}

function setShowValue(path, value) {
  setPath(getSelectedShow(), path, value);
  setDirty(true);
}

function showValue(path) {
  return getPath(getSelectedShow(), path) ?? "";
}

function normalizeValue(value) {
  return String(value || "").trim();
}

function normalizeValues(values) {
  return [...new Set(values.map(normalizeValue).filter(Boolean))];
}

function tokenEntryValues(value) {
  return String(value || "")
    .split(/[,\n/]+/)
    .map(normalizeValue)
    .filter(Boolean);
}

function mergeOptionSets(first, second) {
  const fields = new Set([...Object.keys(first || {}), ...Object.keys(second || {})]);
  return Object.fromEntries(
    [...fields].map((field) => [
      field,
      normalizeValues([...(first[field] || []), ...(second[field] || [])])
    ])
  );
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function humanizeOption(value) {
  return String(value || "")
    .split("-")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function optionDisplayLabel(value) {
  return humanizeOption(value);
}

function setDirty(nextDirty) {
  dirty = nextDirty;
  const saveButton = document.querySelector("#saveButton");
  const status = document.querySelector("#statusMessage");
  if (saveButton) {
    saveButton.disabled = !dirty;
  }
  if (status && dirty) {
    status.textContent = "Unsaved changes";
    status.classList.remove("error");
  }
}

function setEpisodeDirty(nextDirty) {
  episodeDirty = nextDirty;
  const saveButton = document.querySelector("#saveEpisodeButton");
  const status = document.querySelector("#episodeStatusMessage");
  if (saveButton) {
    saveButton.disabled = !episodeDirty;
  }
  if (status && episodeDirty) {
    status.textContent = "Unsaved episode changes";
    status.classList.remove("error");
  }
}

function setOptionsDirty(nextDirty) {
  optionsDirty = nextDirty;
  const saveButton = document.querySelector("#saveOptionsButton");
  const status = document.querySelector("#optionsStatus");
  if (saveButton) {
    saveButton.disabled = !optionsDirty;
  }
  if (status && optionsDirty) {
    status.textContent = "Unsaved option changes";
    status.classList.remove("error");
  }
}

function addOption(field, value) {
  const normalized = normalizeValue(value);
  if (!normalized) {
    return false;
  }

  const current = options[field] || [];
  if (current.includes(normalized)) {
    return false;
  }

  options[field] = [...current, normalized];
  setOptionsDirty(true);
  return true;
}

function removeOption(field, value) {
  options[field] = (options[field] || []).filter((option) => option !== value);
  setOptionsDirty(true);
}

function createField({ path, label, hint, type = "text", span = "", value, readonly = false }) {
  const id = `field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  const inputValue = value ?? recommendationValue(path);
  const readonlyAttr = readonly ? " readonly" : "";

  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <input id="${id}" data-path="${path}" type="${type}" value="${escapeHtml(inputValue)}"${readonlyAttr}>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createShowField({ path, label, hint, type = "text", span = "" }) {
  const id = `show-field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <input id="${id}" data-show-path="${path}" type="${type}" value="${escapeHtml(showValue(path))}">
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createShowTextareaField({ path, label, hint, span = "" }) {
  const id = `show-field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <textarea id="${id}" data-show-path="${path}" rows="5">${escapeHtml(showValue(path))}</textarea>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createShowSelectField({ path, label, hint, values, span = "" }) {
  const id = `show-field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  const value = String(showValue(path) || "");
  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <select id="${id}" data-show-path="${path}">
        ${values.map((option) => `<option value="${escapeHtml(option.value)}" ${String(option.value) === value ? "selected" : ""}>${escapeHtml(option.label)}</option>`).join("")}
      </select>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createSelectField({ path, label, hint, optionKey, span = "" }) {
  const id = `field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  const value = recommendationValue(path);
  const fieldOptions = options[optionKey] || [];
  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <select id="${id}" data-path="${path}" data-option-key="${optionKey}">
        <option value="">Select...</option>
        ${fieldOptions.map((option) => `<option value="${escapeHtml(option)}" ${option === value ? "selected" : ""}>${escapeHtml(optionDisplayLabel(option))}</option>`).join("")}
      </select>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createStaticSelectField({ path, label, hint, values, span = "" }) {
  const id = `field-${path.replaceAll(".", "-")}`;
  const className = ["field", span].filter(Boolean).join(" ");
  const value = String(recommendationValue(path) || "");
  return `
    <div class="${className}">
      <label for="${id}">${label}<span>${path}</span></label>
      <select id="${id}" data-path="${path}">
        ${values.map((option) => `<option value="${escapeHtml(option.value)}" ${String(option.value) === value ? "selected" : ""}>${escapeHtml(option.label)}</option>`).join("")}
      </select>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createTokenField({ path, label, hint, optionKey, span = "" }) {
  const id = `field-${path.replaceAll(".", "-")}`;
  const className = ["field token-field", span].filter(Boolean).join(" ");
  const values = recommendationArray(path);
  return `
    <div class="${className}" data-token-field="${path}" data-option-key="${optionKey}">
      <label for="${id}">${label}<span>${path}</span></label>
      <div class="token-input" data-token-box>
        ${values.map((value) => tokenHtml(value)).join("")}
        <input id="${id}" data-token-entry type="text" placeholder="Type and press Enter">
      </div>
      <div class="suggestions" data-suggestions></div>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function tokenHtml(value) {
  return `
    <span class="token" data-token="${escapeHtml(value)}" title="${escapeHtml(value)}">
      ${escapeHtml(optionDisplayLabel(value))}
      <button type="button" data-remove-token="${escapeHtml(value)}" aria-label="Remove ${escapeHtml(value)}">x</button>
    </span>
  `;
}

function createSection(title, hint, fields) {
  return `
    <section class="section">
      <h3>${title}</h3>
      <p class="hint">${hint}</p>
      <div class="section-grid">${fields.join("")}</div>
    </section>
  `;
}

function renderShowList() {
  const query = searchInput.value.trim().toLowerCase();
  const statusFilter = statusFilterSelect?.value || allStatusesFilterValue;
  const filteredShows = shows.filter((show) => {
    const haystack = `${show.title} ${show.genre} ${show.description}`.toLowerCase();
    const matchesQuery = haystack.includes(query);
    const matchesStatus = statusFilter === allStatusesFilterValue || show.status === statusFilter;
    return matchesQuery && matchesStatus;
  });

  showList.innerHTML = "";
  filteredShows.forEach((show) => {
    const node = showButtonTemplate.content.cloneNode(true);
    const button = node.querySelector(".show-button");
    button.classList.toggle("is-active", show.id === selectedShowId);
    button.addEventListener("click", () => selectShow(show.id));
    node.querySelector(".show-thumb").src = show.posterUrl;
    node.querySelector(".show-title").textContent = show.title;
    node.querySelector(".show-meta").textContent = `${show.genre} / ${show.status} / ${show.stats.episodeCount} episodes`;
    node.querySelector(".show-rating").textContent = formatManualRating(show);
    showList.appendChild(node);
  });
}

function formatManualRating(show) {
  const rating = Number(show.recommendation?.editorial?.qualityLabel);
  return Number.isFinite(rating) ? `Manual rating: ${rating}/5 (higher is better)` : "Manual rating: Not set";
}

function renderHeader() {
  const show = getSelectedShow();
  showHeader.innerHTML = `
    <img class="poster" src="${escapeHtml(show.posterUrl)}" alt="">
    <div class="show-heading">
      <h2>${escapeHtml(show.title)}</h2>
      <p>${escapeHtml(show.description)}</p>
      <p>${show.stats.avgEpisodeSeconds}s avg / ${show.stats.freePreviewEpisodes} free previews / ${show.stats.lockedEpisodes} locked</p>
    </div>
    <div class="header-actions">
      <button class="secondary-button" id="buildShowButton" type="button">Build Show From Episodes</button>
      <button class="secondary-button" id="suggestButton" type="button">Suggest Defaults</button>
      <span class="status" id="statusMessage">Saved</span>
      <button class="primary-button" id="saveButton" type="button" disabled>Save</button>
    </div>
  `;

  document.querySelector("#saveButton").addEventListener("click", saveSelectedShow);
  document.querySelector("#suggestButton").addEventListener("click", applySuggestedDefaults);
  document.querySelector("#buildShowButton").addEventListener("click", buildShowFromEpisodes);
}

function renderEpisodeTagger() {
  const episodes = getSelectedEpisodes();
  if (!episodes.length) {
    episodeTagger.innerHTML = `
      <div class="section">
        <h3>Episode Tags</h3>
        <p class="hint">No episodes are available for this show.</p>
      </div>
    `;
    return;
  }

  if (!selectedEpisodeId || !episodes.some((episode) => episode.id === selectedEpisodeId)) {
    selectedEpisodeId = episodes[0].id;
  }

  const episode = getSelectedEpisode();
  episodeTagger.innerHTML = `
    <section class="section">
      <div class="episode-header">
        <div>
          <h3>Episode Tags</h3>
          <p class="hint">Watch the episode, then tag only the atoms active in this episode.</p>
        </div>
        <div class="episode-actions">
          <span class="status" id="episodeStatusMessage">Episode saved</span>
          <button class="primary-button" id="saveEpisodeButton" type="button" disabled>Save Episode</button>
        </div>
      </div>
      <div class="episode-grid">
        <div class="episode-player">
          ${episode.playbackPath ? `<video controls playsinline poster="${escapeHtml(episode.thumbnailUrl)}" data-playback-path="${escapeHtml(episode.playbackPath)}"></video>` : `<img src="${escapeHtml(episode.thumbnailUrl)}" alt="">`}
          <div class="video-actions">
            <button class="secondary-button" id="rewindButton" type="button">-10s</button>
            <button class="secondary-button" id="replayButton" type="button">Replay</button>
          </div>
          <label class="scrub-control" for="episodeScrubber">
            <span id="currentTimeLabel">0:00</span>
            <input id="episodeScrubber" type="range" min="0" max="1000" value="0" step="1">
            <span id="durationLabel">0:00</span>
          </label>
          <label class="speed-control" for="playbackSpeed">
            Speed
            <select id="playbackSpeed">
              ${[1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3].map((speed) => `<option value="${speed}" ${speed === 1 ? "selected" : ""}>${speed.toFixed(speed % 1 === 0 ? 0 : 2)}x</option>`).join("")}
            </select>
          </label>
          <p class="hint" id="playbackStatus">Loading playback...</p>
        </div>
        <div class="episode-fields">
          <div class="field is-full">
            <label for="episodeSelect">Episode<span>${episode.durationSeconds || 0}s</span></label>
            <select id="episodeSelect">
              ${episodes.map((candidate) => `<option value="${escapeHtml(candidate.id)}" ${candidate.id === episode.id ? "selected" : ""}>Episode ${candidate.episodeNumber}: ${escapeHtml(candidate.title)}</option>`).join("")}
            </select>
            <p class="hint">${escapeHtml(episode.description || "")}</p>
          </div>
          ${createEpisodeTextareaField("scriptNotes", "Script notes", "Paste the plain-language episode beat summary here. This is stored with the episode recommendation metadata.")}
          ${createEpisodeTokenField("activeAtoms", "Active atoms", "Taste atoms actually present in this episode.")}
          ${createEpisodeComboField("emotionalBeat", "Emotional beat", "The dominant emotional moment.", "emotionalBeats")}
          ${createEpisodeSelectField("narrativeRole", "Narrative role", "The episode's story function.", "narrativeRoles")}
          ${createEpisodeTokenField("payoffTypes", "Payoff types", "Specific satisfaction events in this episode.")}
          ${createEpisodeTokenField("pacingTags", "Pacing tags", "How this episode moves or pays off.")}
        </div>
      </div>
    </section>
  `;

  document.querySelector("#episodeSelect").addEventListener("change", (event) => {
    if (episodeDirty && !confirm("Discard unsaved episode changes?")) {
      event.target.value = selectedEpisodeId;
      return;
    }
    selectedEpisodeId = event.target.value;
    setEpisodeDirty(false);
    renderEpisodeTagger();
  });
  document.querySelector("#saveEpisodeButton").addEventListener("click", saveSelectedEpisode);
  document.querySelector("#playbackSpeed")?.addEventListener("change", applyPlaybackSpeed);
  document.querySelector("#rewindButton")?.addEventListener("click", () => seekBy(-10));
  document.querySelector("#replayButton")?.addEventListener("click", replayEpisode);
  document.querySelector("#episodeScrubber")?.addEventListener("input", scrubEpisode);
  attachEpisodeEvents();
  loadEpisodePlayback();
}

function createEpisodeTextareaField(path, label, hint) {
  const episode = getSelectedEpisode();
  const value = episode.recommendation?.[path] || "";
  return `
    <div class="field is-full">
      <label>${label}<span>${path}</span></label>
      <textarea data-episode-path="${path}" rows="6" placeholder="Paste what happens in this episode...">${escapeHtml(value)}</textarea>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createEpisodeTokenField(path, label, hint) {
  const episode = getSelectedEpisode();
  const values = Array.isArray(episode.recommendation?.[path]) ? episode.recommendation[path] : [];
  return `
    <div class="field token-field is-full" data-episode-token-field="${path}" data-option-key="${path}">
      <label>${label}<span>${path}</span></label>
      <div class="token-input" data-token-box>
        ${values.map((value) => tokenHtml(value)).join("")}
        <input data-token-entry type="text" placeholder="Type and press Enter">
      </div>
      <div class="suggestions" data-suggestions></div>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createEpisodeSelectField(path, label, hint, optionKey) {
  const episode = getSelectedEpisode();
  const value = episode.recommendation?.[path] || "";
  return `
    <div class="field">
      <label>${label}<span>${path}</span></label>
      <select data-episode-path="${path}" data-option-key="${optionKey}">
        <option value="">Select...</option>
        ${(options[optionKey] || []).map((option) => `<option value="${escapeHtml(option)}" ${option === value ? "selected" : ""}>${escapeHtml(optionDisplayLabel(option))}</option>`).join("")}
      </select>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function createEpisodeComboField(path, label, hint, optionKey) {
  const episode = getSelectedEpisode();
  const value = episode.recommendation?.[path] || "";
  const datalistId = `episode-${path}-options`;
  return `
    <div class="field">
      <label>${label}<span>${path}</span></label>
      <input data-episode-path="${path}" data-option-key="${optionKey}" list="${datalistId}" value="${escapeHtml(value)}" placeholder="Type or choose">
      <datalist id="${datalistId}">
        ${(options[optionKey] || []).map((option) => `<option value="${escapeHtml(option)}"></option>`).join("")}
      </datalist>
      <p class="hint">${hint}</p>
    </div>
  `;
}

function setEpisodeValue(path, value) {
  const episode = getSelectedEpisode();
  episode.recommendation = episode.recommendation || {};
  episode.recommendation[path] = value;
  setEpisodeDirty(true);
}

function attachEpisodeEvents() {
  episodeTagger.querySelectorAll("[data-episode-token-field]").forEach((field) => attachTokenField(field, {
    getValues: () => {
      const episode = getSelectedEpisode();
      const values = episode.recommendation?.[field.dataset.episodeTokenField];
      return Array.isArray(values) ? values : [];
    },
    setValues: (values) => setEpisodeValue(field.dataset.episodeTokenField, values),
    markOptionsDirty: true
  }));

  episodeTagger.querySelectorAll("[data-episode-path]").forEach((input) => {
    const updateSingleValue = ({ commitOption = false } = {}) => {
      setEpisodeValue(input.dataset.episodePath, input.value);
      if (commitOption && input.dataset.optionKey && input.value && addOption(input.dataset.optionKey, input.value)) {
        renderOptionBank();
      }
    };
    input.addEventListener("input", updateSingleValue);
    input.addEventListener("change", () => updateSingleValue({ commitOption: true }));
    input.addEventListener("keydown", (event) => {
      if (input.tagName === "TEXTAREA") {
        return;
      }

      if (event.key === "Enter" && input.value.trim()) {
        event.preventDefault();
        updateSingleValue({ commitOption: true });
        input.blur();
      }
    });
  });
}

function readEpisodeRecommendation() {
  const episode = getSelectedEpisode();
  const recommendation = structuredClone(episode.recommendation || {});

  episodeTagger.querySelectorAll("[data-episode-path]").forEach((input) => {
    recommendation[input.dataset.episodePath] = input.value;
  });

  return recommendation;
}

async function loadEpisodePlayback() {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  const status = document.querySelector("#playbackStatus");
  const episode = getSelectedEpisode();
  if (!video) {
    if (status) {
      status.textContent = "No playable video asset is configured.";
      status.classList.add("error");
    }
    return;
  }

  try {
    const ticket = await playbackTicketForEpisode(episode);
    attachPlaybackSource(video, episode.id, ticket.playbackUrl);
    attachPlaybackControlEvents(video);
    applyPlaybackSpeed();
    updateScrubber();
    status.textContent = ticket.expiresAt ? `Playback ready until ${new Date(ticket.expiresAt).toLocaleTimeString()}` : "Playback ready";
    status.classList.remove("error");
  } catch (error) {
    status.textContent = error.message;
    status.classList.add("error");
  }
}

async function playbackTicketForEpisode(episode) {
  const cached = playbackSessions.get(episode.id);
  const expiresAt = cached?.expiresAt ? new Date(cached.expiresAt).getTime() : 0;
  const refreshAt = expiresAt - 60_000;
  if (cached?.playbackUrl && (!expiresAt || Date.now() < refreshAt)) {
    return cached;
  }

  const response = await fetch(episode.playbackPath);
  if (!response.ok) {
    throw new Error(response.status === 503
      ? "Playback signing is not configured. Add Cloudflare Stream credentials to .env.local."
      : `Playback request failed with ${response.status}`);
  }

  const ticket = await response.json();
  playbackSessions.set(episode.id, ticket);
  return ticket;
}

function attachPlaybackSource(video, episodeId, playbackUrl) {
  if (video.dataset.loadedEpisodeId === episodeId && video.dataset.loadedPlaybackUrl === playbackUrl) {
    return;
  }

  video.dataset.loadedEpisodeId = episodeId;
  video.dataset.loadedPlaybackUrl = playbackUrl;

  if (video.canPlayType("application/vnd.apple.mpegurl")) {
    video.src = playbackUrl;
  } else if (window.Hls?.isSupported()) {
    if (video._hls) {
      video._hls.destroy();
    }
    const hls = new window.Hls({
      backBufferLength: Number.POSITIVE_INFINITY,
      maxBufferLength: 600,
      maxMaxBufferLength: 1200
    });
    video._hls = hls;
    hls.loadSource(playbackUrl);
    hls.attachMedia(video);
  } else {
    throw new Error("This browser cannot play HLS and hls.js did not load.");
  }
}

function attachPlaybackControlEvents(video) {
  if (video.dataset.controlsAttached === "true") {
    return;
  }

  video.dataset.controlsAttached = "true";
  video.addEventListener("loadedmetadata", updateScrubber);
  video.addEventListener("durationchange", updateScrubber);
  video.addEventListener("timeupdate", updateScrubber);
  video.addEventListener("ended", () => {
    const replayButton = document.querySelector("#replayButton");
    if (replayButton) {
      replayButton.disabled = false;
    }
  });
}

function applyPlaybackSpeed() {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  const speedSelect = document.querySelector("#playbackSpeed");
  if (!video || !speedSelect) {
    return;
  }

  video.playbackRate = Number(speedSelect.value || 1);
}

function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) {
    return "0:00";
  }

  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.floor(seconds % 60).toString().padStart(2, "0");
  return `${minutes}:${remainingSeconds}`;
}

function updateScrubber() {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  const scrubber = document.querySelector("#episodeScrubber");
  const currentTimeLabel = document.querySelector("#currentTimeLabel");
  const durationLabel = document.querySelector("#durationLabel");
  if (!video || !scrubber || !currentTimeLabel || !durationLabel) {
    return;
  }

  const duration = Number.isFinite(video.duration) ? video.duration : 0;
  scrubber.disabled = duration <= 0;
  scrubber.value = duration > 0 ? Math.round((video.currentTime / duration) * 1000) : 0;
  currentTimeLabel.textContent = formatTime(video.currentTime);
  durationLabel.textContent = formatTime(duration);
}

function scrubEpisode() {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  const scrubber = document.querySelector("#episodeScrubber");
  if (!video || !scrubber || !Number.isFinite(video.duration) || video.duration <= 0) {
    return;
  }

  video.currentTime = (Number(scrubber.value) / 1000) * video.duration;
  updateScrubber();
}

function seekBy(seconds) {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  if (!video || !Number.isFinite(video.duration)) {
    return;
  }

  video.currentTime = Math.min(Math.max(video.currentTime + seconds, 0), video.duration);
  updateScrubber();
}

async function replayEpisode() {
  const video = episodeTagger.querySelector("video[data-playback-path]");
  if (!video) {
    return;
  }

  video.currentTime = 0;
  updateScrubber();
  await video.play().catch(() => {});
}

function renderForm() {
  form.innerHTML = [
    createSection("Show Basics", "Public catalog fields used by the app and show info tray.", [
      createShowField({ path: "title", label: "Title", hint: explanations.title }),
      createShowField({ path: "genre", label: "Genre", hint: explanations.genre }),
      createShowSelectField({ path: "status", label: "Status", hint: explanations.status, values: showStatusOptions }),
      createShowTextareaField({ path: "description", label: "Synopsis", hint: explanations.description, span: "is-full" })
    ]),
    createSection("Audience-Facing Hooks", "Short public hooks we can safely show in product surfaces.", [
      createTokenField({ path: "heroTraits", label: "Hero traits", hint: explanations.heroTraits, optionKey: "heroTraits", span: "is-full" })
    ]),
    createSection("Discovery & Similarity", "Fields that drive shelves, show matching, and More Like This.", [
      createSelectField({ path: "primaryGenre", label: "Primary genre", hint: explanations.primaryGenre, optionKey: "primaryGenre" }),
      createTokenField({ path: "microGenres", label: "Micro genres", hint: explanations.microGenres, optionKey: "microGenres", span: "is-full" }),
      createTokenField({ path: "storySignals", label: "Story signals", hint: explanations.storySignals, optionKey: "storySignals", span: "is-full" }),
      createTokenField({ path: "similarShowIds", label: "Similar shows", hint: explanations.similarShowIds, optionKey: "similarShowIds", span: "is-full" })
    ]),
    createSection("Story Engine", "Narrative promise, character dynamics, conflict, and payoffs.", [
      createTokenField({ path: "emotionalFantasies", label: "Emotional fantasies", hint: explanations.emotionalFantasies, optionKey: "emotionalFantasies" }),
      createTokenField({ path: "protagonistArchetypes", label: "Protagonist archetypes", hint: explanations.protagonistArchetypes, optionKey: "protagonistArchetypes" }),
      createTokenField({ path: "counterpartArchetypes", label: "Counterpart archetypes", hint: explanations.counterpartArchetypes, optionKey: "counterpartArchetypes" }),
      createTokenField({ path: "relationshipDynamics", label: "Relationship dynamics", hint: explanations.relationshipDynamics, optionKey: "relationshipDynamics" }),
      createTokenField({ path: "conflictSetups", label: "Conflict setups", hint: explanations.conflictSetups, optionKey: "conflictSetups" }),
      createTokenField({ path: "powerDynamics", label: "Power dynamics", hint: explanations.powerDynamics, optionKey: "powerDynamics" }),
      createTokenField({ path: "payoffTypes", label: "Payoff types", hint: explanations.payoffTypes, optionKey: "payoffTypes" }),
      createTokenField({ path: "pacingPromises", label: "Pacing promises", hint: explanations.pacingPromises, optionKey: "pacingPromises" }),
      createTokenField({ path: "endingPromises", label: "Ending promises", hint: explanations.endingPromises, optionKey: "endingPromises" })
    ]),
    createSection("World & Presentation", "World logic and visual surface used for narrow, explainable matching.", [
      createTokenField({ path: "characterSystem", label: "Character system", hint: explanations.characterSystem, optionKey: "characterSystem" }),
      createTokenField({ path: "worldType", label: "World type", hint: explanations.worldType, optionKey: "worldType" }),
      createTokenField({ path: "tone", label: "Tone", hint: explanations.tone, optionKey: "tone" }),
      createTokenField({ path: "visualStyle", label: "Visual style", hint: explanations.visualStyle, optionKey: "visualStyle" }),
      createSelectField({ path: "contentLineage.type", label: "Content lineage", hint: explanations.contentLineage, optionKey: "contentLineageType" })
    ]),
    createSection("Editorial Controls", explanations.editorial, [
      createStaticSelectField({
        path: "editorial.qualityLabel",
        label: "Quality (higher is better)",
        hint: explanations.qualityLabel,
        values: [
          { value: 1, label: "1" },
          { value: 2, label: "2" },
          { value: 3, label: "3" },
          { value: 4, label: "4" },
          { value: 5, label: "5" }
        ]
      })
    ])
  ].join("");

  attachFormEvents();
}

function attachFormEvents() {
  form.querySelectorAll("input[data-show-path], select[data-show-path], textarea[data-show-path]").forEach((input) => {
    const updateShowValue = () => {
      setShowValue(input.dataset.showPath, input.value);
      renderHeader();
      setDirty(true);
      renderShowList();
    };
    input.addEventListener(input.tagName === "SELECT" ? "change" : "input", updateShowValue);
  });

  form.querySelectorAll("input[data-path], select[data-path]").forEach((input) => {
    input.addEventListener("input", () => {
      setRecommendationValue(input.dataset.path, input.value);
    });
    input.addEventListener("change", () => {
      setRecommendationValue(input.dataset.path, input.value);
      const optionKey = input.dataset.optionKey;
      if (optionKey && input.value) {
        addOption(optionKey, input.value);
        renderOptionBank();
      }
    });
  });

  form.querySelectorAll("[data-token-field]").forEach((field) => attachTokenField(field, {
    getValues: () => recommendationArray(field.dataset.tokenField),
    setValues: (values) => setRecommendationValue(field.dataset.tokenField, values),
    markOptionsDirty: true
  }));
}

function attachTokenField(field, { getValues, setValues, markOptionsDirty }) {
  const optionKey = field.dataset.optionKey;
  const input = field.querySelector("[data-token-entry]");
  const suggestions = field.querySelector("[data-suggestions]");
  const box = field.querySelector("[data-token-box]");

  function redraw() {
    const values = getValues();
    box.querySelectorAll("[data-token]").forEach((token) => token.remove());
    input.insertAdjacentHTML("beforebegin", values.map((value) => tokenHtml(value)).join(""));
    attachRemoveButtons();
    renderSuggestions();
  }

  function addValue(value) {
    const normalizedEntries = tokenEntryValues(value);
    if (!normalizedEntries.length) {
      return;
    }

    const nextValues = normalizeValues([...getValues(), ...normalizedEntries]);
    setValues(nextValues);
    if (markOptionsDirty && optionKey !== "similarShowIds") {
      let changedOptions = false;
      normalizedEntries.forEach((entry) => {
        changedOptions = addOption(optionKey, entry) || changedOptions;
      });
      if (changedOptions) {
        renderOptionBank();
      }
    }
    input.value = "";
    redraw();
  }

  function removeValue(value) {
    setValues(getValues().filter((item) => item !== value));
    redraw();
  }

  function attachRemoveButtons() {
    field.querySelectorAll("[data-remove-token]").forEach((button) => {
      button.addEventListener("click", () => removeValue(button.dataset.removeToken));
    });
  }

  function renderSuggestions() {
    const query = input.value.trim().toLowerCase();
    const values = getValues();
    const fieldOptions = optionKey === "similarShowIds"
      ? shows.map((show) => show.id).filter((id) => id !== selectedShowId)
      : options[optionKey] || [];
    const matches = fieldOptions
      .filter((option) => !values.includes(option))
      .filter((option) => !query || option.toLowerCase().includes(query) || optionDisplayLabel(option).toLowerCase().includes(query));

    suggestions.innerHTML = groupedSuggestionsHtml(optionKey, matches, query);
    suggestions.querySelectorAll("[data-suggestion]").forEach((button) => {
      button.addEventListener("click", () => addValue(button.dataset.suggestion));
    });
  }

  input.addEventListener("input", () => {
    renderSuggestions();
    if (input.value.trim()) {
      setValues(getValues());
    }
  });
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === "," || event.key === "/" || (event.key === "Tab" && input.value.trim())) {
      event.preventDefault();
      addValue(input.value);
    } else if (event.key === "Backspace" && !input.value) {
      const values = getValues();
      if (values.length) {
        removeValue(values[values.length - 1]);
      }
    }
  });
  box.addEventListener("click", () => input.focus());
  attachRemoveButtons();
  renderSuggestions();
}

function groupedSuggestionsHtml(optionKey, matches, query = "") {
  const buckets = optionBuckets[optionKey];
  if (!buckets) {
    return matches.slice(0, 12).map(suggestionButtonHtml).join("");
  }

  const matchedSet = new Set(matches);
  const used = new Set();
  const groups = [];
  if (optionKey === "activeAtoms") {
    const recommendedMatches = getRecommendedEpisodeAtoms()
      .filter((option) => matchedSet.has(option));
    recommendedMatches.forEach((option) => used.add(option));
    groups.push(["Recommended for This Show", recommendedMatches]);
  }

  Object.entries(buckets).forEach(([bucket, bucketOptions]) => {
    const bucketMatches = bucketOptions.filter((option) => matchedSet.has(option));
    bucketMatches.forEach((option) => used.add(option));
    groups.push([bucket, bucketMatches]);
  });
  const uncategorized = matches.filter((option) => !used.has(option));
  const mergedGroups = groups.map(([bucket, bucketMatches]) => [
    bucket,
    bucket === "New / Uncategorized" ? [...bucketMatches, ...uncategorized] : bucketMatches
  ]);

  return mergedGroups
    .filter(([, bucketMatches]) => bucketMatches.length)
    .map(([bucket, bucketMatches]) => `
      <div class="suggestion-group">
        <div class="suggestion-heading">${escapeHtml(bucket)}</div>
        <div class="suggestion-buttons">
          ${bucketMatches.map(suggestionButtonHtml).join("")}
        </div>
      </div>
    `)
    .join("");
}

function getRecommendedEpisodeAtoms() {
  return normalizeValues(getActiveEpisodeStoryTypes().flatMap((storyType) => episodeAtomStoryPalettes[storyType] || []));
}

function getActiveEpisodeStoryTypes() {
  const show = getSelectedShow();
  const recommendation = show?.recommendation || {};
  const signals = new Set([
    ...(recommendation.storySignals || []),
    ...(recommendation.microGenres || []),
    ...(recommendation.relationshipDynamics || []),
    ...(recommendation.conflictSetups || []),
    ...(recommendation.powerDynamics || [])
  ]);
  const activeStoryTypes = Object.entries(episodeAtomStorySignals)
    .filter(([, storySignals]) => storySignals.some((signal) => signals.has(signal)))
    .map(([storyType]) => storyType);

  return activeStoryTypes;
}

function suggestionButtonHtml(option) {
  return `
    <button type="button" data-suggestion="${escapeHtml(option)}" title="${escapeHtml(option)}">
      ${escapeHtml(optionDisplayLabel(option))}
    </button>
  `;
}

function readFormRecommendation() {
  const recommendation = structuredClone(getSelectedShow().recommendation);
  form.querySelectorAll("input[data-path], select[data-path]").forEach((input) => {
    setPath(recommendation, input.dataset.path, input.value);
  });
  form.querySelectorAll("[data-token-field]").forEach((field) => {
    const tokenValues = [...field.querySelectorAll("[data-token]")]
      .map((token) => token.dataset.token);
    const pendingValue = field.querySelector("[data-token-entry]")?.value;
    setPath(recommendation, field.dataset.tokenField, normalizeValues([...tokenValues, ...tokenEntryValues(pendingValue)]));
  });
  return recommendation;
}

function readFormShowBasics() {
  const show = getSelectedShow();
  const basics = {
    title: show.title,
    description: show.description,
    genre: show.genre,
    status: show.status
  };

  form.querySelectorAll("[data-show-path]").forEach((input) => {
    setPath(basics, input.dataset.showPath, input.value);
  });

  return basics;
}

function renderOptionBank() {
  const fieldKeys = visibleOptionFields.filter((key) => Object.hasOwn(options, key));
  if (!fieldKeys.includes(selectedOptionField)) {
    selectedOptionField = fieldKeys[0] || "primaryGenre";
  }
  const values = options[selectedOptionField] || [];
  optionBank.innerHTML = `
    <div class="option-bank-header">
      <div>
        <p class="eyebrow">Controlled Vocabulary</p>
        <h3>Option Bank</h3>
        <p class="hint">Values added to a show are saved here automatically. You can also add or remove reusable values by field.</p>
      </div>
      <div class="option-actions">
        <span class="status" id="optionsStatus">Options saved</span>
        <button class="primary-button" id="saveOptionsButton" type="button" ${optionsDirty ? "" : "disabled"}>Save Options</button>
      </div>
    </div>
    <div class="option-bank-grid">
      <div class="field">
        <label for="optionFieldSelect">Field<span>option bank</span></label>
        <select id="optionFieldSelect">
          ${fieldKeys.map((key) => `<option value="${key}" ${key === selectedOptionField ? "selected" : ""}>${escapeHtml(optionLabels[key])}</option>`).join("")}
        </select>
      </div>
      <div class="field option-editor" data-token-field="optionEditor" data-option-key="${escapeHtml(selectedOptionField)}">
        <label for="optionEditorInput">${escapeHtml(optionLabels[selectedOptionField])}<span>${values.length} values</span></label>
        <div class="token-input" data-token-box>
          ${values.map((value) => tokenHtml(value)).join("")}
          <input id="optionEditorInput" data-token-entry type="text" placeholder="Type and press Enter">
        </div>
        <div class="suggestions" data-suggestions></div>
        <p class="hint">Removing a value here only removes it from future suggestions. Existing shows keep their saved metadata.</p>
      </div>
    </div>
  `;

  document.querySelector("#optionFieldSelect").addEventListener("change", (event) => {
    selectedOptionField = event.target.value;
    renderOptionBank();
  });
  document.querySelector("#saveOptionsButton").addEventListener("click", saveOptions);
  attachTokenField(optionBank.querySelector("[data-token-field='optionEditor']"), {
    getValues: () => options[selectedOptionField] || [],
    setValues: (values) => {
      options[selectedOptionField] = values;
      setOptionsDirty(true);
    },
    markOptionsDirty: false
  });
}

async function loadEpisodesForShow(showId) {
  if (episodesByShowId[showId]) {
    return;
  }

  const response = await fetch(`/api/shows/${encodeURIComponent(showId)}/episodes`);
  if (!response.ok) {
    throw new Error(`Unable to load episodes: ${response.status}`);
  }
  const payload = await response.json();
  episodesByShowId[showId] = payload.episodes;
}

async function selectShow(showId) {
  if (dirty && !confirm("Discard unsaved changes?")) {
    return;
  }
  if (episodeDirty && !confirm("Discard unsaved episode changes?")) {
    return;
  }

  selectedShowId = showId;
  selectedEpisodeId = "";
  setDirty(false);
  setEpisodeDirty(false);
  await loadEpisodesForShow(showId);
  renderShowList();
  renderHeader();
  renderEpisodeTagger();
  renderForm();
}

function uniqueFrequent(values, limit = 8) {
  const counts = new Map();
  values.filter(Boolean).forEach((value) => counts.set(value, (counts.get(value) || 0) + 1));
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([value]) => value);
}

function valuesInOptionSet(values, optionKey) {
  const allowed = new Set(options[optionKey] || []);
  return values.filter((value) => allowed.has(value));
}

function buildShowFromEpisodes() {
  const show = getSelectedShow();
  const recommendations = getSelectedEpisodes().map((episode) => episode.recommendation || {});
  const activeAtoms = recommendations.flatMap((recommendation) => recommendation.activeAtoms || []);
  show.recommendation.emotionalFantasies = uniqueFrequent(valuesInOptionSet(activeAtoms, "emotionalFantasies"), 10);
  show.recommendation.relationshipDynamics = uniqueFrequent(valuesInOptionSet(activeAtoms, "relationshipDynamics"), 8);
  show.recommendation.conflictSetups = uniqueFrequent(valuesInOptionSet(activeAtoms, "conflictSetups"), 8);
  show.recommendation.powerDynamics = uniqueFrequent(valuesInOptionSet(activeAtoms, "powerDynamics"), 8);
  show.recommendation.payoffTypes = uniqueFrequent(recommendations.flatMap((recommendation) => recommendation.payoffTypes || []), 8);
  show.recommendation.pacingPromises = uniqueFrequent(recommendations.flatMap((recommendation) => recommendation.pacingTags || []), 6);
  setDirty(true);
  renderForm();
}

function defaultsForShow(show) {
  const title = show.title.toLowerCase();
  const genre = show.genre.toLowerCase();
  const recommendation = structuredClone(show.recommendation);

  recommendation.primaryGenre = genre === "sports" ? "sports" : genre === "romance" ? "romance" : "drama";

  if (title.includes("love island")) {
    recommendation.microGenres = ["dating-competition", "reality-competition", "villa-romance"];
    recommendation.tone = ["playful", "flirty", "dramatic"];
    recommendation.emotionalFantasies = ["chosen-over-rival", "romantic-validation", "social-domination"];
    recommendation.protagonistArchetypes = ["flirty-contestant", "romantic-underdog"];
    recommendation.counterpartArchetypes = ["charming-heartthrob", "tempting-new-arrival", "arrogant-rival"];
    recommendation.relationshipDynamics = ["competitive-dating", "love-triangle", "couple-switching"];
    recommendation.conflictSetups = ["new-arrival-disruption", "romantic-rivalry", "competition-elimination"];
    recommendation.powerDynamics = ["social-rank-shifting", "public-selection"];
    recommendation.payoffTypes = ["chosen-at-recoupling", "rival-rejected", "public-romantic-claim"];
    recommendation.pacingPromises = ["fast-hook", "constant-reversals", "cliffhanger-heavy"];
    recommendation.endingPromises = ["couple-endgame"];
    recommendation.characterSystem = title.includes("fruit") || title.includes("candy")
      ? ["fruit-characters", "anthropomorphic-food"]
      : [];
    recommendation.worldType = title.includes("fruit") || title.includes("candy")
      ? ["food-world"]
      : [];
    recommendation.visualStyle = ["ai-generated", "bright", "reality-style"];
    recommendation.contentLineage.type = "original";
  } else if (title.includes("basketball")) {
    recommendation.microGenres = ["sports-underdog"];
    recommendation.tone = ["dramatic", "tense"];
    recommendation.emotionalFantasies = ["underdog-triumph", "recognition-and-fame"];
    recommendation.protagonistArchetypes = ["gifted-rookie", "ambitious-underdog"];
    recommendation.counterpartArchetypes = ["arrogant-rival", "demanding-coach"];
    recommendation.relationshipDynamics = ["teammate-rivalry", "mentor-protege"];
    recommendation.conflictSetups = ["career-sabotage", "wrongfully-accused"];
    recommendation.powerDynamics = ["rival-has-advantage", "outsider-gains-leverage"];
    recommendation.payoffTypes = ["competition-win", "career-win"];
    recommendation.pacingPromises = ["fast-hook", "escalates-every-episode"];
    recommendation.endingPromises = ["status-restored"];
    recommendation.characterSystem = ["human-characters"];
    recommendation.worldType = ["real-world"];
    recommendation.visualStyle = ["sports-action"];
    recommendation.contentLineage.type = "original";
  } else if (title.includes("balenciaga")) {
    recommendation.microGenres = title.includes("breaking bad") ? ["crime-parody", "fashion-satire"] : ["fantasy-parody", "fashion-satire"];
    recommendation.tone = ["absurd", "glamorous", "dark"];
    recommendation.emotionalFantasies = ["power-fantasy", "recognition-and-fame", "social-domination"];
    recommendation.protagonistArchetypes = title.includes("breaking bad") ? ["schemer"] : ["ordinary-person-chosen"];
    recommendation.counterpartArchetypes = title.includes("breaking bad") ? ["crime-boss", "corrupt-institution"] : ["dark-lord", "elite-mean-girl"];
    recommendation.relationshipDynamics = ["power-struggle", "rivals-to-allies"];
    recommendation.conflictSetups = ["hidden-identity", "public-scandal"];
    recommendation.powerDynamics = ["hidden-identity-power", "public-status-reversal"];
    recommendation.payoffTypes = ["status-reveal", "villain-exposed"];
    recommendation.pacingPromises = ["fast-hook", "constant-reversals"];
    recommendation.endingPromises = ["open-ended"];
    recommendation.characterSystem = ["human-characters"];
    recommendation.worldType = title.includes("breaking bad") ? ["real-world"] : ["fantasy-world"];
    recommendation.visualStyle = ["ai-generated", "ai-stylized", "fashion-editorial", "meme-native"];
    recommendation.contentLineage.type = "mashup";
  } else if (title.includes("ww2")) {
    recommendation.microGenres = ["alternate-history", "war-fantasy"];
    recommendation.tone = ["dark", "tense", "dramatic"];
    recommendation.emotionalFantasies = ["survival-against-odds", "secret-power-reveal", "justice-served"];
    recommendation.protagonistArchetypes = ["ordinary-person-chosen", "reluctant-hero"];
    recommendation.counterpartArchetypes = ["dark-lord", "corrupt-institution"];
    recommendation.relationshipDynamics = ["unlikely-allies", "rivals-to-allies"];
    recommendation.conflictSetups = ["wrongfully-accused", "powerful-family-opposes"];
    recommendation.powerDynamics = ["hidden-identity-power", "outsider-gains-leverage"];
    recommendation.payoffTypes = ["secret-identity-reveal", "dramatic-rescue", "villain-exposed"];
    recommendation.pacingPromises = ["cliffhanger-heavy", "escalates-every-episode"];
    recommendation.endingPromises = ["villain-punished"];
    recommendation.characterSystem = ["human-characters"];
    recommendation.worldType = ["alternate-history", "fantasy-world"];
    recommendation.visualStyle = ["ai-generated", "ai-stylized", "cinematic", "moody"];
    recommendation.contentLineage.type = "mashup";
  }

  return recommendation;
}

function applySuggestedDefaults() {
  const show = getSelectedShow();
  show.recommendation = defaultsForShow(show);
  setDirty(true);
  renderForm();
}

async function saveSelectedShow() {
  const show = getSelectedShow();
  const status = document.querySelector("#statusMessage");
  const saveButton = document.querySelector("#saveButton");
  const hadOptionsDirty = optionsDirty;
  saveButton.disabled = true;
  status.textContent = "Saving...";
  status.classList.remove("error");

  try {
    const response = await fetch(`/api/shows/${encodeURIComponent(show.id)}/recommendation`, {
      method: "PUT",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({
        show: readFormShowBasics(),
        recommendation: readFormRecommendation()
      })
    });

    if (!response.ok) {
      throw new Error(`Save failed with ${response.status}`);
    }

    const payload = await response.json();
    const index = shows.findIndex((candidate) => candidate.id === show.id);
    shows[index] = payload.show;
    options = hadOptionsDirty ? mergeOptionSets(options, payload.options) : payload.options;
    setDirty(false);
    setOptionsDirty(hadOptionsDirty);
    status.textContent = "Saved";
    renderShowList();
    renderForm();
    renderOptionBank();
  } catch (error) {
    status.textContent = error.message;
    status.classList.add("error");
    saveButton.disabled = false;
  }
}

async function saveSelectedEpisode() {
  const episode = getSelectedEpisode();
  const recommendation = readEpisodeRecommendation();
  const status = document.querySelector("#episodeStatusMessage");
  const saveButton = document.querySelector("#saveEpisodeButton");
  const hadOptionsDirty = optionsDirty;
  saveButton.disabled = true;
  status.textContent = "Saving episode...";
  status.classList.remove("error");

  try {
    const response = await fetch(`/api/episodes/${encodeURIComponent(episode.id)}/recommendation`, {
      method: "PUT",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({ recommendation })
    });

    if (!response.ok) {
      throw new Error(`Episode save failed with ${response.status}`);
    }

    const payload = await response.json();
    const episodes = getSelectedEpisodes();
    const index = episodes.findIndex((candidate) => candidate.id === episode.id);
    episodes[index] = payload.episode;
    options = hadOptionsDirty ? mergeOptionSets(options, payload.options) : payload.options;
    setEpisodeDirty(false);
    setOptionsDirty(hadOptionsDirty);
    status.textContent = "Episode saved";
    renderEpisodeTagger();
    renderOptionBank();
  } catch (error) {
    status.textContent = error.message;
    status.classList.add("error");
    saveButton.disabled = false;
  }
}

async function saveOptions() {
  const status = document.querySelector("#optionsStatus");
  const saveButton = document.querySelector("#saveOptionsButton");
  saveButton.disabled = true;
  status.textContent = "Saving options...";
  status.classList.remove("error");

  try {
    const response = await fetch("/api/options", {
      method: "PUT",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({ options })
    });

    if (!response.ok) {
      throw new Error(`Option save failed with ${response.status}`);
    }

    const payload = await response.json();
    options = payload.options;
    setOptionsDirty(false);
    renderForm();
    renderOptionBank();
  } catch (error) {
    status.textContent = error.message;
    status.classList.add("error");
    saveButton.disabled = false;
  }
}

async function loadInitialData() {
  const [showsResponse, optionsResponse] = await Promise.all([
    fetch("/api/shows"),
    fetch("/api/options")
  ]);
  if (!showsResponse.ok) {
    throw new Error(`Unable to load shows: ${showsResponse.status}`);
  }
  if (!optionsResponse.ok) {
    throw new Error(`Unable to load options: ${optionsResponse.status}`);
  }

  const showsPayload = await showsResponse.json();
  const optionsPayload = await optionsResponse.json();
  shows = showsPayload.shows;
  options = optionsPayload.options;
  selectedShowId = shows[0]?.id || "";
  if (selectedShowId) {
    await loadEpisodesForShow(selectedShowId);
  }
  renderShowList();
  if (selectedShowId) {
    renderHeader();
    renderEpisodeTagger();
    renderForm();
  }
  renderOptionBank();
}

searchInput.addEventListener("input", renderShowList);
statusFilterSelect?.addEventListener("change", renderShowList);
window.addEventListener("beforeunload", (event) => {
  if (!dirty && !episodeDirty && !optionsDirty) {
    return;
  }

  event.preventDefault();
  event.returnValue = "";
});

loadInitialData().catch((error) => {
  showHeader.innerHTML = `<p class="error">${escapeHtml(error.message)}</p>`;
});
