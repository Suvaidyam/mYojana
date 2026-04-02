/**
 * mYojana Service Worker
 *
 * Served at /sw.js via Frappe's www/ routing (files in www/ are accessible
 * at their corresponding URL path), giving this SW root scope over the entire
 * Frappe desk at /app/*.
 *
 * Caching strategies
 * ──────────────────
 * • Static assets  (/assets/*)           → Cache-first, stale-while-revalidate
 * • App shell      (/app, /app/*)        → Network-first, fall back to cache
 * • Master data    (frappe.client.get_list for reference doctypes)
 *                                        → Network-first, fall back to Cache API
 * • Mutating APIs  (save / insert / delete / login / logout)
 *                                        → Network-only — NEVER serve stale data
 * • Everything else                      → Network-first, no offline fallback
 */

const STATIC_CACHE = "myojana-static-v1";
const SHELL_CACHE = "myojana-shell-v1";
const DATA_CACHE = "myojana-data-v1";

const ALL_CACHES = [STATIC_CACHE, SHELL_CACHE, DATA_CACHE];

/**
 * frappe.client API methods that read reference/master doctypes.
 * Responses for these are safe to serve from cache when offline.
 * Identified by the cmd= parameter in the POST body.
 */
const CACHEABLE_METHODS = new Set([
	"frappe.client.get_list",
	"frappe.client.get_value",
	"frappe.client.get",
	"myojana.apis.myojana_setting.get_myojana_setting",
]);

/**
 * frappe.client API methods that mutate data or manage auth.
 * These must NEVER be served from cache.
 */
const NEVER_CACHE_METHODS = new Set([
	"frappe.client.save",
	"frappe.client.insert",
	"frappe.client.delete",
	"frappe.client.bulk_update",
	"frappe.client.set_value",
	"frappe.client.submit",
	"frappe.client.cancel",
	"login",
	"logout",
	"frappe.auth.get_logged_user",
]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isStaticAsset(url) {
	return url.pathname.startsWith("/assets/");
}

function isAppShell(url) {
	return url.pathname === "/app" || url.pathname.startsWith("/app/");
}

function isApiCall(url) {
	return url.pathname.startsWith("/api/method/");
}

/**
 * Extracts the Frappe method name from a request.
 * Frappe API POSTs send cmd= in the URL query string.
 */
function getFrappeMethod(url) {
	return url.searchParams.get("cmd") || "";
}

function isMutatingCall(url) {
	const method = getFrappeMethod(url);
	if (!method) return false;
	// Treat any unknown /api/method/ call as potentially mutating unless
	// it is explicitly in CACHEABLE_METHODS
	if (NEVER_CACHE_METHODS.has(method)) return true;
	return false;
}

function isCacheableApiCall(url) {
	const method = getFrappeMethod(url);
	return method && CACHEABLE_METHODS.has(method);
}

// ---------------------------------------------------------------------------
// Network-first strategy — try network, fall back to cache
// ---------------------------------------------------------------------------

async function networkFirst(request, cacheName) {
	try {
		const networkResponse = await fetch(request.clone());
		if (networkResponse.ok) {
			const cache = await caches.open(cacheName);
			cache.put(request, networkResponse.clone());
		}
		return networkResponse;
	} catch (_err) {
		const cached = await caches.match(request);
		return cached || Response.error();
	}
}

// ---------------------------------------------------------------------------
// Cache-first strategy — serve from cache, refresh in background
// ---------------------------------------------------------------------------

async function cacheFirst(request, cacheName) {
	const cached = await caches.match(request);
	// Always kick off a background refresh so the cache stays warm
	const fetchAndUpdate = fetch(request.clone())
		.then((networkResponse) => {
			if (networkResponse.ok) {
				caches.open(cacheName).then((cache) => cache.put(request, networkResponse));
			}
		})
		.catch(() => {});

	if (cached) {
		// Don't await the background refresh — return cached immediately
		fetchAndUpdate;
		return cached;
	}
	// Cache miss — wait for network
	return fetch(request);
}

// ---------------------------------------------------------------------------
// Install — pre-cache the app shell
// ---------------------------------------------------------------------------

self.addEventListener("install", (event) => {
	event.waitUntil(
		caches
			.open(SHELL_CACHE)
			.then((cache) =>
				cache.addAll([
					"/app",
					"/assets/myojana/manifest.json",
				])
			)
			.then(() => self.skipWaiting())
	);
});

// ---------------------------------------------------------------------------
// Activate — remove stale caches from previous SW versions
// ---------------------------------------------------------------------------

self.addEventListener("activate", (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) =>
				Promise.all(
					keys
						.filter((key) => !ALL_CACHES.includes(key))
						.map((key) => caches.delete(key))
				)
			)
			.then(() => self.clients.claim())
	);
});

// ---------------------------------------------------------------------------
// Fetch — route every request to the appropriate strategy
// ---------------------------------------------------------------------------

self.addEventListener("fetch", (event) => {
	const url = new URL(event.request.url);

	// Only handle same-origin requests
	if (url.origin !== self.location.origin) return;

	// --- Mutating API calls: pass straight through, never cache ---
	if (isApiCall(url) && isMutatingCall(url)) {
		// Let the browser handle it; no event.respondWith() means default fetch
		return;
	}

	// --- Cacheable master data API calls: network-first with cache fallback ---
	if (isApiCall(url) && isCacheableApiCall(url)) {
		event.respondWith(networkFirst(event.request, DATA_CACHE));
		return;
	}

	// --- Other unknown API calls: network-only ---
	if (isApiCall(url)) {
		return; // default browser fetch
	}

	// --- Static assets: cache-first, stale-while-revalidate ---
	if (isStaticAsset(url)) {
		event.respondWith(cacheFirst(event.request, STATIC_CACHE));
		return;
	}

	// --- App shell (/app/*): network-first, fall back to cached shell ---
	if (isAppShell(url)) {
		event.respondWith(networkFirst(event.request, SHELL_CACHE));
		return;
	}

	// --- Everything else: network-only ---
});
