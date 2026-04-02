/**
 * mYojana PWA bootstrap — runs in every Frappe desk session.
 *
 * Responsibilities:
 *   1. Inject <link rel="manifest"> and Apple iOS meta tags into <head>
 *   2. Register the service worker at /sw.js
 *   3. Pre-cache master/reference doctype data in IndexedDB (24 h TTL)
 *      so dropdowns remain usable when the network is unavailable
 */

const MYOJANA_PWA_DB = "myojana-pwa";
const MYOJANA_PWA_DB_VERSION = 1;
const MASTER_DATA_STORE = "master_data";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Reference doctypes whose list data is safe to cache offline.
 * These change rarely and are needed for every beneficiary form fill.
 */
const MASTER_DOCTYPES = [
	"State",
	"District",
	"Block",
	"Village",
	"Camp",
	"Centre",
	"Sub Centre",
	"Religion",
	"Caste Category",
	"Education",
	"Occupation",
	"Occupational Category",
	"Marital Status",
	"House Types",
	"Source Of Information",
	"ID Document",
	"Scheme",
	"PWD Master",
	"Social Vulnerable Category",
	"Milestone Category",
];

// ---------------------------------------------------------------------------
// Phase 1 — Manifest & iOS meta tags
// ---------------------------------------------------------------------------

function injectManifest() {
	if (document.querySelector("link[rel=\"manifest\"]")) return;
	const link = document.createElement("link");
	link.rel = "manifest";
	link.href = "/assets/myojana/manifest.json";
	document.head.appendChild(link);
}

function injectIOSTags() {
	const metas = [
		{ name: "apple-mobile-web-app-capable", content: "yes" },
		{ name: "apple-mobile-web-app-status-bar-style", content: "default" },
		{ name: "apple-mobile-web-app-title", content: "mYojana" },
	];
	metas.forEach(({ name, content }) => {
		if (document.querySelector(`meta[name="${name}"]`)) return;
		const meta = document.createElement("meta");
		meta.name = name;
		meta.content = content;
		document.head.appendChild(meta);
	});

	if (!document.querySelector("link[rel=\"apple-touch-icon\"]")) {
		const icon = document.createElement("link");
		icon.rel = "apple-touch-icon";
		icon.href = "/assets/myojana/images/mYojana.png";
		document.head.appendChild(icon);
	}
}

// ---------------------------------------------------------------------------
// Phase 2 — Service worker registration
// ---------------------------------------------------------------------------

function registerServiceWorker() {
	if (!("serviceWorker" in navigator)) return;

	navigator.serviceWorker
		.register("/sw.js", { scope: "/" })
		.then((registration) => {
			// Trigger an update check on each page load
			registration.update();
		})
		.catch((err) => {
			console.error("[mYojana PWA] Service worker registration failed:", err);
		});
}

// ---------------------------------------------------------------------------
// Phase 3 — IndexedDB master data pre-caching
// ---------------------------------------------------------------------------

function openDB() {
	return new Promise((resolve, reject) => {
		const req = indexedDB.open(MYOJANA_PWA_DB, MYOJANA_PWA_DB_VERSION);
		req.onupgradeneeded = (event) => {
			const db = event.target.result;
			if (!db.objectStoreNames.contains(MASTER_DATA_STORE)) {
				db.createObjectStore(MASTER_DATA_STORE, { keyPath: "doctype" });
			}
		};
		req.onsuccess = (event) => resolve(event.target.result);
		req.onerror = (event) => reject(event.target.error);
	});
}

function getCached(db, doctype) {
	return new Promise((resolve, reject) => {
		const tx = db.transaction(MASTER_DATA_STORE, "readonly");
		const req = tx.objectStore(MASTER_DATA_STORE).get(doctype);
		req.onsuccess = (event) => resolve(event.target.result || null);
		req.onerror = (event) => reject(event.target.error);
	});
}

function putCached(db, doctype, records) {
	return new Promise((resolve, reject) => {
		const tx = db.transaction(MASTER_DATA_STORE, "readwrite");
		const req = tx.objectStore(MASTER_DATA_STORE).put({
			doctype,
			records,
			cached_at: Date.now(),
		});
		req.onsuccess = () => resolve();
		req.onerror = (event) => reject(event.target.error);
	});
}

function isFresh(entry) {
	return entry && Date.now() - entry.cached_at < CACHE_TTL_MS;
}

async function cacheSingleDoctype(db, doctype) {
	try {
		const existing = await getCached(db, doctype);
		if (isFresh(existing)) return; // still valid — skip

		const result = await new Promise((resolve, reject) => {
			frappe.call({
				method: "frappe.client.get_list",
				args: {
					doctype,
					fields: ["name"],
					limit_page_length: 5000,
				},
				callback: (r) => resolve(r.message || []),
				error: reject,
			});
		});

		await putCached(db, doctype, result);
	} catch (_err) {
		// Non-fatal — field workers may not have permission to read every doctype
	}
}

async function preCacheMasterData() {
	// Only run when the user is logged in (frappe.session.user is set)
	if (!frappe.session || frappe.session.user === "Guest") return;

	let db;
	try {
		db = await openDB();
	} catch (_err) {
		return; // IndexedDB unavailable (private browsing, etc.) — silent fail
	}

	// Cache doctypes one at a time in the background to avoid hammering the server
	for (const doctype of MASTER_DOCTYPES) {
		await cacheSingleDoctype(db, doctype);
	}
}

// ---------------------------------------------------------------------------
// Bootstrap — run after Frappe desk is ready
// ---------------------------------------------------------------------------

frappe.ready(() => {
	injectManifest();
	injectIOSTags();
	registerServiceWorker();

	// Defer master data caching to after the desk has finished loading
	setTimeout(() => {
		preCacheMasterData();
	}, 3000);
});
