import defaultCatalog from "../catalog.json";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type",
};

const VALID_EVENTS = new Set(["impression", "tap", "view"]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }

    if (url.pathname === "/v1/catalog" && request.method === "GET") {
      return handleCatalog(url, env);
    }
    if (url.pathname === "/v1/event" && request.method === "POST") {
      return handleEvent(request, env);
    }
    if (url.pathname === "/v1/stats" && request.method === "GET") {
      return handleStats(url, env);
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

async function handleCatalog(url, env) {
  const catalog = await loadCatalog(env);
  const exclude = new Set(
    (url.searchParams.get("exclude") || "")
      .split(",")
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean)
  );
  const apps = catalog.apps
    .filter((app) => !exclude.has(String(app.bundleId).toLowerCase()))
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999));

  return json(
    { version: catalog.version, updatedAt: catalog.updatedAt, developer: catalog.developer, apps },
    200,
    { "cache-control": "public, max-age=300, s-maxage=600" }
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
  if (!VALID_EVENTS.has(event) || !appId) {
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
    bump(env, `c:${event}:${appId}:${day}`),
  ]);
}

async function bump(env, key) {
  const current = parseInt((await env.MIDGAR.get(key)) || "0", 10) || 0;
  await env.MIDGAR.put(key, String(current + 1));
}

async function handleStats(url, env) {
  if (!env || !env.MIDGAR) return json({ error: "no_storage" }, 503);
  if (env.STATS_KEY && url.searchParams.get("key") !== env.STATS_KEY) {
    return json({ error: "unauthorized" }, 401);
  }
  const totals = {};
  let cursor;
  do {
    const page = await env.MIDGAR.list({ prefix: "c:", cursor });
    for (const k of page.keys) {
      const parts = k.name.split(":");
      if (parts.length !== 3) continue;
      const [, event, appId] = parts;
      const value = parseInt((await env.MIDGAR.get(k.name)) || "0", 10) || 0;
      totals[appId] = totals[appId] || {};
      totals[appId][event] = (totals[appId][event] || 0) + value;
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
