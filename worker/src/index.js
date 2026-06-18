import defaultCatalog from "../catalog.json";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type,authorization",
};

const CATALOG_CACHE = "public, max-age=60, s-maxage=60, stale-while-revalidate=600";
const VALID_EVENTS = new Set(["impression", "tap"]);
const DAILY_TTL_SECONDS = 60 * 60 * 24 * 120;
const MAX_APP_ID_LENGTH = 16;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }
    if (url.pathname === "/v1/catalog" && request.method === "GET") {
      return handleCatalog(request, url, env);
    }
    if (url.pathname === "/v1/event" && request.method === "POST") {
      return handleEvent(request, env);
    }
    if (url.pathname === "/v1/stats" && request.method === "GET") {
      return handleStats(request, url, env);
    }
    if (url.pathname === "/" || url.pathname === "/health") {
      return json({
        service: "midgar-catalog",
        endpoints: ["/v1/catalog", "/v1/event", "/v1/stats"],
        apps: defaultCatalog.apps.length,
      });
    }
    return json({ error: "not_found" }, 404);
  },
};

async function loadCatalog(env) {
  if (env && env.MIDGAR) {
    const override = await env.MIDGAR.get("catalog", "json").catch(() => null);
    if (override && Array.isArray(override.apps)) return override;
  }
  return defaultCatalog;
}

async function handleCatalog(request, url, env) {
  const catalog = await loadCatalog(env);
  const exclude = new Set(
    (url.searchParams.get("exclude") || "")
      .split(",")
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean)
  );
  const seen = new Set();
  const apps = catalog.apps
    .filter((app) => !exclude.has(String(app.bundleId).toLowerCase()))
    .filter((app) => {
      const id = String(app.appId);
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    })
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999));

  const etag = `"${catalog.version}-${catalog.updatedAt || ""}-${[...exclude].sort().join(",")}"`;
  if (request.headers.get("if-none-match") === etag) {
    return new Response(null, {
      status: 304,
      headers: { ...JSON_HEADERS, etag, "cache-control": CATALOG_CACHE },
    });
  }

  return json(
    { version: catalog.version, updatedAt: catalog.updatedAt, developer: catalog.developer, apps },
    200,
    { "cache-control": CATALOG_CACHE, etag }
  );
}

async function handleEvent(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const event = String(body.event || "").toLowerCase();
  const appId = String(body.appId || "").replace(/[^0-9]/g, "");
  if (!VALID_EVENTS.has(event) || !appId || appId.length > MAX_APP_ID_LENGTH) {
    return json({ error: "invalid_event" }, 400);
  }
  await recordEvent(env, event, appId).catch(() => {});
  return new Response(null, { status: 204, headers: JSON_HEADERS });
}

async function recordEvent(env, event, appId) {
  if (!env || !env.MIDGAR) return;
  const day = new Date().toISOString().slice(0, 10);
  await Promise.all([
    bump(env, `c:${event}:${appId}`),
    bump(env, `c:${event}:${appId}:${day}`, { expirationTtl: DAILY_TTL_SECONDS }),
  ]);
}

async function bump(env, key, options = {}) {
  const current = parseInt((await env.MIDGAR.get(key)) || "0", 10) || 0;
  const next = current + 1;
  await env.MIDGAR.put(key, String(next), { ...options, metadata: { count: next } });
}

function authorized(request, url, env) {
  const header = request.headers.get("authorization") || "";
  const bearer = header.startsWith("Bearer ") ? header.slice(7) : "";
  const key = bearer || url.searchParams.get("key") || "";
  return key.length > 0 && key === env.STATS_KEY;
}

async function handleStats(request, url, env) {
  if (!env || !env.MIDGAR) return json({ error: "no_storage" }, 503);
  if (!env.STATS_KEY) return json({ error: "stats_unconfigured" }, 503);
  if (!authorized(request, url, env)) return json({ error: "unauthorized" }, 401);

  const totals = {};
  let cursor;
  do {
    const page = await env.MIDGAR.list({ prefix: "c:", cursor });
    for (const entry of page.keys) {
      const parts = entry.name.split(":");
      if (parts.length !== 3) continue;
      const [, event, appId] = parts;
      const count = (entry.metadata && entry.metadata.count) || 0;
      totals[appId] = totals[appId] || {};
      totals[appId][event] = (totals[appId][event] || 0) + count;
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return json({ totals });
}

function json(data, status = 200, extra = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...JSON_HEADERS, ...extra },
  });
}
