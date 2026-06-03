<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";

const BASE_WRAP_URL = "https://c168l.top/?id=256798963";
const CSV_CANDIDATE_PATHS = ["/crawl_output/game.csv", "/crawl_output/game.ccsv"];

const loading = ref(true);
const error = ref("");
const games = ref([]);

const introVisible = ref(true);
const introProgress = ref(9.5);
const introLogs = ref([]);
const introRainRows = [
  "A7F0 92CC 1D9A B30E F2C4 7B01 88DD 3E90",
  "B11E 0CA7 9DF3 45AA E820 7C91 3D55 A8F1",
  "3E7A 5C10 0BAD C9F2 6671 1AE2 4D40 E9CC",
  "91D3 2B77 8ECA 40FD A3B2 C1E0 55D4 6A13",
  "2CC8 FDA0 37BE 0E1A A8B6 9D14 65B3 C7EE",
  "0A4E 77BD 31CC D2A4 5E91 F0A8 46CF 8B22",
  "D8A9 3CF6 14B0 5A27 E39D 70AF C2EE 1B68"
];
const introHudLines = [
  "SYS_NODE_ID: 0x3A0D7F",
  "ENCRYPTION_BYPASS: AES-256 (BYPASSING)",
  "WARN: ROOT ACCESS OVERRIDE IN PROGRESS"
];
let introTimer = null;
let introInterval = null;

const logPool = [
  "[SYS] BOOTING STEALTH NODE...",
  "[NET] Ghost tunnel handshake: SUCCESS",
  "[ALR] WARNING: root access override signal detected",
  "[FW ] Cloud edge bypass routine injected",
  "[KEY] Rotating entropy seed for link wrap",
  "[DB ] Syncing hidden game feed chunk",
  "[ENC] AES-256 capsule generation online",
  "[ALR] Threat monitor: elevated privileges active",
  "[AUD] Anti-bot signature randomizer loaded",
  "[MUX] Secure redirect matrix stabilized"
];

const fallbackGames = [
  {
    index: 3,
    source: "HOT GAME",
    name: "Quyet Chien Gianh Tien Thuong",
    imageUrl: "https://m.c168i.top/game_pictures/g/2865/CL/200/3/2000135/custom.avif"
  }
];

const visibleGames = computed(() =>
  games.value.filter((game) => {
    const source = normalizeSearchText(game?.source);
    const name = normalizeSearchText(game?.name);
    return source !== "casino" && !name.includes("casino");
  })
);

const gameCount = computed(() => visibleGames.value.length);
const unlockLines = [
  "Tắt chế độ theo dõi tài khoản từ trang game",
  "Kích hoạt tỉ lệ maxwin nổ hũ",
  "Tối đa BIGWIN và SCATTER liên tục cho tài khoản"
];

const DISPLAY_LIMIT = 3;
const PINNED_GAME_INDEX = 3;
const PINNED_GAME_NAME = normalizeSearchText("Quyết Chiến Giành Tiền Thưởng");
const SESSION_KEY = `session-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const displayedGames = ref([]);

const primaryGateLink = computed(() => BASE_WRAP_URL);

watch(
  visibleGames,
  () => {
    refreshDisplayedGames();
  },
  { immediate: true }
);

onMounted(async () => {
  introLogs.value = logPool.slice(0, 3);
  introInterval = window.setInterval(() => {
    const delta = 2.5 + Math.random() * 5.5;
    introProgress.value = Math.min(100, introProgress.value + delta);

    if (Math.random() > 0.45) {
      const next = logPool[Math.floor(Math.random() * logPool.length)];
      introLogs.value = [...introLogs.value, next].slice(-5);
    }

    if (introProgress.value >= 100) {
      window.clearInterval(introInterval);
      introInterval = null;
      introTimer = window.setTimeout(() => {
        introVisible.value = false;
      }, 400);
    }
  }, 120);

  loading.value = true;
  error.value = "";

  try {
    games.value = await loadGamesFromCsv();
  } catch (err) {
    error.value = err instanceof Error ? err.message : "Loi khong xac dinh";
    games.value = fallbackGames.map((row) => {
      const winRateValue = buildWinRate(row.name, row.index);
      const seed = hashString(`${row.name}-${row.index}-${getSessionKey()}`);
      return {
        ...row,
        seed,
        winRateValue,
        winRate: `${winRateValue.toFixed(1)}%`,
        wrappedLink: makeWrappedLink(row.name, row.index, seed)
      };
    });
  } finally {
    loading.value = false;
  }
});

onBeforeUnmount(() => {
  if (introTimer) {
    window.clearTimeout(introTimer);
  }
  if (introInterval) {
    window.clearInterval(introInterval);
  }
});

async function loadGamesFromCsv() {
  let lastError = new Error("CSV rong hoac sai dinh dang.");

  for (const path of CSV_CANDIDATE_PATHS) {
    try {
      const response = await fetch(path, { cache: "no-store" });
      if (!response.ok) {
        lastError = new Error(`Khong doc duoc ${path} (${response.status})`);
        continue;
      }

      const text = await response.text();
      if (looksLikeHtml(text)) {
        lastError = new Error(`${path} khong phai CSV (nhan ve HTML).`);
        continue;
      }

      const parsed = parseCsv(text)
        .map((row, rowIndex) => normalizeRow(row, rowIndex))
        .filter(Boolean);

      if (parsed.length) {
        return parsed;
      }

      lastError = new Error(`${path} rong hoac sai dinh dang.`);
    } catch (err) {
      lastError = err instanceof Error ? err : new Error("Loi khong xac dinh khi doc CSV.");
    }
  }

  throw lastError;
}

function parseCsv(text) {
  const cleanText = text.replace(/^\uFEFF/, "");
  const lines = cleanText.split(/\r?\n/).filter((line) => line.trim());
  if (!lines.length) {
    return [];
  }

  const delimiter = detectDelimiter(lines[0]);
  const headers = splitCsvLine(lines[0], delimiter).map((header) => normalizeHeaderKey(stripQuotes(header)));

  if (!headers.length || !headers.some(Boolean)) {
    return [];
  }

  return lines.slice(1).map((line) => {
    const values = splitCsvLine(line, delimiter).map(stripQuotes);
    return headers.reduce((acc, key, idx) => {
      if (!key) {
        return acc;
      }
      acc[key] = values[idx] ?? "";
      return acc;
    }, {});
  });
}

function splitCsvLine(line, delimiter = ",") {
  const escaped = delimiter.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const splitter = new RegExp(`${escaped}(?=(?:[^"]*"[^"]*")*[^"]*$)`, "g");
  return line.split(splitter);
}

function detectDelimiter(headerLine) {
  const candidates = [",", ";", "\t", "|"];
  const best = candidates
    .map((delimiter) => ({ delimiter, count: splitCsvLine(headerLine, delimiter).length }))
    .sort((a, b) => b.count - a.count)[0];

  return best && best.count > 1 ? best.delimiter : ",";
}

function stripQuotes(value) {
  return value.replace(/^"|"$/g, "").replace(/""/g, '"').trim();
}

function normalizeHeaderKey(header) {
  const normalized = header.toLowerCase().replace(/\s+/g, "_");
  const aliasMap = {
    stt: "index",
    rank: "index",
    id: "index",
    title: "name",
    game: "name",
    game_name: "name",
    category: "source",
    type: "source",
    image: "image_url",
    imageurl: "image_url",
    image_link: "image_url",
    thumbnail: "image_url",
    picture: "image_url",
    thumb: "image_url",
    localfile: "local_file"
  };

  return aliasMap[normalized] || normalized;
}

function looksLikeHtml(text) {
  return /^\s*<(?:!doctype\s+html|html|body|head)\b/i.test(text);
}

function normalizeRow(row, rowIndex) {
  if (!row.name || !row.image_url) {
    return null;
  }

  const index = Number.parseInt(row.index, 10) || rowIndex + 1;
  const source = row.source || "GAME";
  if (normalizeSearchText(source) === "casino") {
    return null;
  }
  const seed = hashString(`${row.name}-${index}-${getSessionKey()}`);
  const winRateValue = buildWinRate(row.name, index);
  const status = normalizeStatus(row.status);
  const localFile = normalizeLocalImagePath(row.local_file || "");
  const remoteImageUrl = row.image_url;

  return {
    index,
    source,
    name: row.name,
    imageUrl: localFile || remoteImageUrl,
    remoteImageUrl,
    localFile,
    status,
    seed,
    winRateValue,
    winRate: `${winRateValue.toFixed(1)}%`,
    wrappedLink: makeWrappedLink(row.name, index, seed)
  };
}

function normalizeLocalImagePath(path) {
  const value = (path || "").toString().trim();
  if (!value) {
    return "";
  }
  if (/^https?:\/\//i.test(value)) {
    return value;
  }
  return value.startsWith("/") ? value : `/${value}`;
}

function onImageError(event, fallbackUrl) {
  if (!fallbackUrl) {
    return;
  }
  const image = event.target;
  if (!(image instanceof HTMLImageElement)) {
    return;
  }
  if (image.dataset.fallbackApplied === "1") {
    return;
  }
  image.dataset.fallbackApplied = "1";
  image.src = fallbackUrl;
}

function normalizeStatus(rawStatus) {
  const value = (rawStatus || "ok").toString().trim().toLowerCase();
  if (["ok", "active", "ready", "on"].includes(value)) {
    return { text: "Đã kích hoạt", tone: "ok" };
  }
  if (["maintenance", "maintain", "hold", "pending"].includes(value)) {
    return { text: "Bao tri", tone: "hold" };
  }
  if (["off", "down", "error", "blocked"].includes(value)) {
    return { text: "Tam dung", tone: "off" };
  }
  return { text: "Đã kích hoạt", tone: "ok" };
}

function normalizeSearchText(value) {
  return (value || "")
    .toString()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function shuffleList(items) {
  const list = [...items];
  for (let i = list.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
}

function pickRandomGames(allGames, limit) {
  if (!Array.isArray(allGames) || !allGames.length || limit <= 0) {
    return [];
  }

  const pinnedGame =
    allGames.find(
      (game) =>
        Number(game?.index) === PINNED_GAME_INDEX && normalizeSearchText(game?.name) === PINNED_GAME_NAME
    ) || null;
  const randomPool = pinnedGame ? allGames.filter((game) => game !== pinnedGame) : [...allGames];

  if (!pinnedGame) {
    if (allGames.length <= limit) {
      return shuffleList(allGames);
    }
    return shuffleList(allGames).slice(0, limit);
  }

  const remaining = Math.max(limit - 1, 0);
  if (remaining === 0) {
    return [pinnedGame];
  }

  const randomSelection = shuffleList(randomPool).slice(0, remaining);
  return [pinnedGame, ...randomSelection];
}

function refreshDisplayedGames() {
  const next = pickRandomGames(visibleGames.value, DISPLAY_LIMIT);
  const prevSignature = displayedGames.value.map((game) => `${game.index}-${game.name}`).join("|");
  const nextSignature = next.map((game) => `${game.index}-${game.name}`).join("|");

  if (visibleGames.value.length > DISPLAY_LIMIT && prevSignature === nextSignature) {
    displayedGames.value = pickRandomGames(visibleGames.value, DISPLAY_LIMIT);
    return;
  }

  displayedGames.value = next;
}

function getSessionKey() {
  return SESSION_KEY;
}

function hashString(input) {
  let hash = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function buildWinRate(name, index) {
  const randomValue = Math.random();
  return 92 + randomValue * 7;
}

function makeWrappedLink() {
  return BASE_WRAP_URL;
}

function meterWidth(value) {
  const bounded = Math.max(0, Math.min(100, value));
  return `${bounded}%`;
}
</script>

<template>
  <div class="page">
    <transition name="intro-fade">
      <div v-if="introVisible" class="hacker-intro" aria-hidden="true">
        <aside class="matrix-hud">
          <p v-for="line in introHudLines" :key="line">{{ line }}</p>
        </aside>

        <div class="matrix-rain" aria-hidden="true">
          <span v-for="(line, idx) in introRainRows" :key="`${line}-${idx}`" :style="{ '--col': idx }">{{ line }}</span>
        </div>

        <div class="hacker-noise"></div>
        <div class="intro-glow ig-1"></div>
        <div class="intro-glow ig-2"></div>

        <section class="decrypt-shell">
          <header class="decrypt-head">
            <div class="skull-badge">
              <span>☠</span>
            </div>
            <div>
              <p class="boot-text">CỔNG LIÊN KẾT BẢO MẬT TỰ ĐỘNG</p>
              <h2 class="decrypt-title" style="font-size: clamp(1.4rem, 4.8vw, 2.8rem);" data-text="ĐANG XÓA MÃ ẨN...">ĐANG XÓA MÃ ẨN...</h2>
              <p class="boot-text alt">tiến trình can thiệp và gỡ bỏ mã ngầm</p>
            </div>
            <div class="threat-chip">ROOT OVERRIDE</div>
          </header>

          <div class="decrypt-grid">
            <div class="decrypt-main">
              <div class="hacker-progress">
                <div class="hacker-progress-fill" :style="{ width: `${introProgress.toFixed(1)}%` }"></div>
              </div>
              <p class="boot-percent">execution: {{ introProgress.toFixed(2) }}%</p>

              <div class="status-row">
                <span>handshake ok</span>
                <span>signal masked</span>
                <span>trace blocked</span>
              </div>
            </div>

            <div class="decrypt-side">
              <div class="alert-card">
                <strong>⚠ intrusion alert</strong>
                <span>elevated privilege detected</span>
              </div>

              <div class="hacker-log">
                <p v-for="(line, idx) in introLogs" :key="`${line}-${idx}`">{{ line }}</p>
              </div>
            </div>
          </div>
        </section>
      </div>
    </transition>

    <div class="aurora a1" aria-hidden="true"></div>
    <div class="aurora a2" aria-hidden="true"></div>
    <div class="grid-overlay" aria-hidden="true"></div>

    <section class="content">
      <p v-if="loading" class="info">Đang tải dữ liệu game...</p>
      <p v-else-if="error" class="info warn">Không đọc được CSV, đang dùng dữ liệu fallback. Chi tiết: {{ error }}</p>

      <section v-if="!loading" class="unlock-panel">
        <div class="unlock-card">
          <p class="unlock-tag">SYSTEM UNLOCKED</p>
          <h2>Xóa mã ẩn và kích hoạt Maxwin thành công</h2>

          <div class="unlock-cta-wrap">
            <a class="unlock-cta" :href="primaryGateLink" target="_blank" rel="noopener noreferrer">
              <span class="cta-main"><span class="hand-icon">👇</span> BẤM VÀO ĐÂY ĐỂ VÀO GAME <span class="hand-icon">👇</span></span>
              <span class="cta-sub">Áp dụng cho tài khoản đăng ký mới sau khi xóa mã ẩn</span>
            </a>
          </div>

          <ul>
            <li v-for="line in unlockLines" :key="line">{{ line }}</li>
          </ul>
        </div>
      </section>

      <div class="game-grid">
        <article v-for="(game, idx) in displayedGames" :key="`${game.index}-${game.name}`" class="game-card" :style="{ '--idx': idx }">
          <div class="thumb-wrap">
            <img
              :src="game.imageUrl"
              :alt="game.name"
              loading="lazy"
              @error="onImageError($event, game.remoteImageUrl)"
            />
            <span class="source">{{ game.source }}</span>
          </div>

          <div class="body">
            <p class="optimized-title">ĐÃ TỐI ƯU TỈ LỆ THẮNG</p>
            <h2>{{ game.name }}</h2>

            <div class="stats">
              <span class="rate-label">Tỉ lệ Maxwin:</span>
              <strong>{{ game.winRate }}</strong>
            </div>

            <div class="status-row-card">
              <span class="status-badge" :class="`tone-${game.status.tone}`">{{ game.status.text }}</span>
            </div>

            <div class="meter">
              <div class="fill" :style="{ width: meterWidth(game.winRateValue) }"></div>
            </div>
          </div>
        </article>
      </div>
    </section>
  </div>
</template>
