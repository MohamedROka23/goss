import express from "express";
import cors from "cors";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { initializeApp, applicationDefault } from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";
import { randomBytes, scryptSync, timingSafeEqual } from "crypto";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, "db.json");
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "";
if (!ADMIN_PASSWORD) {
  console.warn(
    "[SECURITY] ADMIN_PASSWORD is not set. The single master-password login and " +
      "team registration are disabled. Export ADMIN_PASSWORD in the environment."
  );
}
// Authenticated sessions: one random token per login, so the shared static
// token can never be extracted from the APK and reused by other users.
const sessions = new Map(); // token -> session user
const SESSION_IDLE_MS = 12 * 60 * 60 * 1000; // 12 hours idle
const SESSION_MAX_MS = 90 * 24 * 60 * 60 * 1000; // 90 days absolute

function sessionUser(token) {
  const s = token ? sessions.get(token) : null;
  if (!s) return null;
  const now = Date.now();
  if (now - s.lastSeen > SESSION_IDLE_MS || now - s.createdAt > SESSION_MAX_MS) {
    sessions.delete(token);
    return null;
  }
  // Deleted accounts are blocked immediately: if the team member no longer
  // exists (or was switched to a blocked state) the token stops working even
  // before its expiry, so a removed admin cannot keep using the app.
  const db = loadDb();
  const live = (db.users || []).find((u) => u.id === s.id);
  if (!live) {
    sessions.delete(token);
    return null;
  }
  // Reflect live role/permission changes on the next request so a promoted/
  // demoted member immediately sees the correct panels (never the stale set
  // captured at login time).
  s.role = live.role ?? s.role;
  s.permissions = [...(live.permissions || [...DEFAULT_PERMISSIONS.admin])];
  s.lastSeen = now;
  return s;
}

function issueSession(user) {
  const token = randomBytes(24).toString("hex");
  sessions.set(token, {
    id: user.id ?? "",
    name: user.name ?? "",
    email: user.email ?? "",
    role: user.role ?? "admin",
    permissions: [...(user.permissions || [...DEFAULT_PERMISSIONS.admin])],
    createdAt: Date.now(),
    lastSeen: Date.now(),
  });
  return token;
}

function bearerToken(header) {
  return (header || "").startsWith("Bearer ") ? header.slice(7) : "";
}

// Periodic session cleanup (every 10 minutes)
setInterval(() => {
  const now = Date.now();
  for (const [k, s] of sessions) {
    if (now - s.lastSeen > SESSION_IDLE_MS || now - s.createdAt > SESSION_MAX_MS) {
      sessions.delete(k);
    }
  }
}, 10 * 60 * 1000).unref();

// Unique resource ids keep their stable prefix (u-, p-, r-, pu-, ex-, n-)
// with a random suffix so concurrent creates can never collide.
function newId(prefix) {
  return `${prefix}-${Date.now()}-${randomBytes(5).toString("hex")}`;
}

// --- Failed-login guard & rate limiting ------------------------------------
// A cheap in-memory firewall that throttles brute-force and abuse. Real
// deployments should front this with a reverse proxy (nginx), but this keeps
// a plain `node server/index.js` safe enough for a small deployment.
const loginAttempts = new Map(); // key -> { count, blockUntil }
const RATE_MAX = 180; // requests per 60s per IP (app polls multiple streams)
const RATE_WINDOW_MS = 60_000;
const LOGIN_FAIL_MAX = 5;
const LOGIN_BLOCK_MS = 15 * 60_000;
const ipHits = new Map(); // ip -> { count, resetAt }

function isLocalhost(peer) {
  return peer === "::1" || peer === "127.0.0.1" || peer === "::ffff:127.0.0.1";
}

// The client-supplied X-Forwarded-For header is only trusted when the socket
// peer is a local reverse proxy; a remote caller must never be able to spoof
// its IP and bypass the login/rate limits.
function clientIp(req) {
  const peer = req.socket.remoteAddress || "unknown";
  if (isLocalhost(peer)) {
    const f = (req.headers["x-forwarded-for"] || "").split(",")[0].trim();
    if (f) return f;
  }
  return peer;
}

function abuseKey(ip, email) {
  return `${ip}|${String(email || "").toLowerCase()}`;
}

function clearExpired(map) {
  const now = Date.now();
  for (const [k, v] of map) {
    if ((v.blockUntil && v.blockUntil <= now) || (v.resetAt && v.resetAt <= now)) map.delete(k);
  }
}

function logFailure(ip, email) {
  const key = abuseKey(ip, email);
  const now = Date.now();
  if (!loginAttempts.has(key)) {
    loginAttempts.set(key, { count: 0, blockUntil: 0 });
  }
  const rec = loginAttempts.get(key);
  if (rec.blockUntil > 0 && rec.blockUntil <= now) {
    loginAttempts.set(key, { count: 0, blockUntil: 0 });
  }
  const updated = loginAttempts.get(key);
  updated.count += 1;
  if (updated.count >= LOGIN_FAIL_MAX) {
    updated.blockUntil = now + LOGIN_BLOCK_MS;
    updated.count = 0;
    console.warn(`[FIREWALL] Locked login for ${key} until ${new Date(updated.blockUntil).toISOString()}`);
  }
}

function loginBlocked(ip, email) {
  clearExpired(loginAttempts);
  const rec = loginAttempts.get(abuseKey(ip, email));
  return rec && rec.blockUntil > Date.now() ? rec.blockUntil : 0;
}

function clearLoginFailures(ip, email) {
  loginAttempts.delete(abuseKey(ip, email));
}

// Simple rate limiter keyed by IP over a rolling window.
function rateLimit(req, res, next) {
  const key = clientIp(req);
  clearExpired(ipHits);
  const rec = ipHits.get(key) || { count: 0, resetAt: Date.now() + RATE_WINDOW_MS };
  rec.count += 1;
  ipHits.set(key, rec);
  res.setHeader("X-RateLimit-Limit", String(RATE_MAX));
  res.setHeader("X-RateLimit-Remaining", String(Math.max(0, RATE_MAX - rec.count)));
  if (rec.count > RATE_MAX) {
    return res.status(429).json({ error: "Too many requests" });
  }
  next();
}

// A tiny denial-of-service guard: reject malformed JSON with 400 instead of
// letting it run the request body through the whole pipeline.
function basicSecurity(req, res, next) {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-XSS-Protection", "0");
  res.setHeader(
    "Strict-Transport-Security",
    "max-age=31536000; includeSubDomains"
  );
  res.setHeader(
    "Permissions-Policy",
    "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
  );
  res.setHeader(
    "Content-Security-Policy",
    "default-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
  );
  // API responses carry time-sensitive data (sessions, accounting): never let
  // a proxy or browser cache them.
  if (req.path.startsWith("/api")) {
    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  }
  if (req.method !== "GET" && req.body && typeof req.body !== "object") {
    return res.status(400).json({ error: "Invalid request body" });
  }
  next();
}

// Cap the size of every textual field so very large payloads can't pollute
// the store or exhaust memory (each field is bounded regardless of body size).
const MAX_TEXT_LEN = 4000;
const MIN_PASSWORD_LEN = 8;
const MAX_IMPORT_ROWS = 5000;
const MAX_REQUEST_ITEMS = 200;
const MAX_JOURNAL_LINES = 100;
const TEXT_FIELDS = new Set([
  "name", "email", "password", "code", "supplier", "notes", "description",
  "productId", "category", "unit", "nameEn", "nameAr", "descEn", "descAr",
  "productNameEn", "productNameAr", "company", "phone", "title", "body", "role",
]);

function guardFieldLengths(req, res, next) {
  if (req.body && typeof req.body === "object") {
    for (const [k, v] of Object.entries(req.body)) {
      if (TEXT_FIELDS.has(k) && typeof v === "string" && v.length > MAX_TEXT_LEN) {
        return res.status(400).json({ error: `Field '${k}' is too long (max ${MAX_TEXT_LEN} chars)` });
      }
    }
  }
  next();
}

// --- Local (offline) data store --------------------------------------------

// Passwords are stored as scrypt hashes. Legacy plaintext values are migrated
// on load so existing credentials keep working unchanged.
const SCRYPT_KEYLEN = 32;

function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(String(password), salt, SCRYPT_KEYLEN).toString("hex");
  return `scrypt$${salt}$${hash}`;
}

function verifyPassword(password, stored) {
  if (!stored) return false;
  if (stored.startsWith("scrypt$")) {
    const parts = stored.split("$");
    if (parts.length !== 3) return false;
    const computed = scryptSync(String(password), parts[1], SCRYPT_KEYLEN);
    const expected = Buffer.from(parts[2], "hex");
    return expected.length === computed.length && timingSafeEqual(expected, computed);
  }
  // Legacy plaintext password until it gets migrated on the next load.
  return stored === password;
}

// Permission keys for team members (kept in sync with lib/models/models.dart)
const PERMISSION_KEYS = ["requests", "customers", "quotes", "purchases", "profit", "expenses", "tracking", "team", "accounting", "chat"];
const DEFAULT_PERMISSIONS = {
  super: [...PERMISSION_KEYS],
  admin: [...PERMISSION_KEYS],
  delegate: ["requests", "customers", "tracking"],
};
const TEAM_ROLES = ["super", "admin", "delegate"];

const STATUS_LABELS = {
  fresh: { en: "New request", ar: "Ø·Ù„Ø¨ Ø¬Ø¯ÙŠØ¯" },
  accepted: { en: "Order received â€” we got your request", ar: "ØªÙ… Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø·Ù„Ø¨" },
  preparing: { en: "Your order is being prepared", ar: "Ø¬Ø§Ø±ÙŠ Ø§Ù„ØªØ¬Ù‡ÙŠØ²" },
  arriving: { en: "On the way to your location", ar: "Ø¬Ø§Ø±ÙŠ Ø§Ù„ÙˆØµÙˆÙ„ Ù„Ù„Ù…ÙˆÙ‚Ø¹" },
  delivering: { en: "Out for delivery", ar: "Ø¬Ø§Ø±ÙŠ Ø§Ù„ØªØ³Ù„ÙŠÙ…" },
  delivered: { en: "Delivered", ar: "ØªÙ… Ø§Ù„ØªØ³Ù„ÙŠÙ…" },
  confirmed: { en: "Delivery confirmed", ar: "Ù…Ø¤ÙƒØ¯ Ø§Ù„ØªØ³Ù„ÙŠÙ…" },
  rejected: { en: "Delivery rejected by customer", ar: "ØªÙ… Ø±ÙØ¶ Ø§Ù„ØªØ³Ù„ÙŠÙ…" },
};

// First-boot super admin password comes ONLY from the environment. When no
// admin password is configured the installer gets a strong random one that is
// logged once at boot — never a hardcoded default.
const SEED_ADMIN_PASSWORD = secureSeedPassword();

function secureSeedPassword() {
  const fromEnv = process.env.GOSS_ADMIN_PASSWORD || process.env.ADMIN_PASSWORD;
  return fromEnv || randomBytes(18).toString("base64url");
}

const seed = {
  products: [
    {
      id: "veg-tomato",
      category: "vegetables",
      unit: "kg",
      price: 18.5,
      nameEn: "Fresh Tomatoes",
      nameAr: "Ø·Ù…Ø§Ø·Ù… Ø·Ø§Ø²Ø¬Ø©",
      descEn: "Farm-fresh tomatoes under unbroken cold-chain.",
      descAr: "Ø·Ù…Ø§Ø·Ù… Ø·Ø§Ø²Ø¬Ø© Ù…Ù† Ø§Ù„Ù…Ø²Ø±Ø¹Ø© Ø¶Ù…Ù† Ø³Ù„Ø³Ù„Ø© ØªØ¨Ø±ÙŠØ¯ Ù…ØªØµÙ„Ø©.",
    },
    {
      id: "veg-potato",
      category: "vegetables",
      unit: "kg",
      price: 12,
      nameEn: "Potatoes",
      nameAr: "Ø¨Ø·Ø§Ø·Ø³",
      descEn: "Sorted potatoes for hospitality and corporate kitchens.",
      descAr: "Ø¨Ø·Ø§Ø·Ø³ Ù…ÙØ±ÙˆØ²Ø© Ù„Ù…Ø·Ø§Ø¨Ø® Ø§Ù„ÙÙ†Ø§Ø¯Ù‚ ÙˆØ§Ù„Ø´Ø±ÙƒØ§Øª.",
    },
    {
      id: "veg-onion",
      category: "vegetables",
      unit: "kg",
      price: 14,
      nameEn: "Onions",
      nameAr: "Ø¨ØµÙ„",
      descEn: "Bulk onions with international sorting standards.",
      descAr: "Ø¨ØµÙ„ Ø¨ÙƒÙ…ÙŠØ§Øª ÙƒØ¨ÙŠØ±Ø© ÙˆÙÙ‚ Ù…Ø¹Ø§ÙŠÙŠØ± ÙØ±Ø² Ø¯ÙˆÙ„ÙŠØ©.",
    },
    {
      id: "veg-cucumber",
      category: "vegetables",
      unit: "kg",
      price: 16,
      nameEn: "Cucumbers",
      nameAr: "Ø®ÙŠØ§Ø±",
      descEn: "Premium cucumbers for HORECA supply.",
      descAr: "Ø®ÙŠØ§Ø± ÙØ§Ø®Ø± Ù„ØªÙˆØ±ÙŠØ¯ Ù‚Ø·Ø§Ø¹ Ø§Ù„Ø¶ÙŠØ§ÙØ©.",
    },
    {
      id: "veg-lettuce",
      category: "vegetables",
      unit: "kg",
      price: 22,
      nameEn: "Lettuce",
      nameAr: "Ø®Ø³",
      descEn: "Crisp lettuce packed for corporate catering.",
      descAr: "Ø®Ø³ Ù…Ù‚Ø±Ù…Ø´ Ù…Ø¹Ø¨Ø£ Ù„Ù„ÙƒÙŠØªØ±ÙŠÙ†Ø¬ Ø§Ù„Ù…Ø¤Ø³Ø³ÙŠ.",
    },
    {
      id: "fru-orange",
      category: "fruits",
      unit: "kg",
      price: 20,
      nameEn: "Oranges",
      nameAr: "Ø¨Ø±ØªÙ‚Ø§Ù„",
      descEn: "Seasonal oranges packed to export grade.",
      descAr: "Ø¨Ø±ØªÙ‚Ø§Ù„ Ù…ÙˆØ³Ù…ÙŠ Ø¨ØªØ¹Ø¨Ø¦Ø© Ø¯Ø±Ø¬Ø© ØªØµØ¯ÙŠØ±.",
    },
    {
      id: "fru-apple",
      category: "fruits",
      unit: "kg",
      price: 35,
      nameEn: "Apples",
      nameAr: "ØªÙØ§Ø­",
      descEn: "Hand-selected apples for hospitality service.",
      descAr: "ØªÙØ§Ø­ Ù…Ù†ØªÙ‚Ù‰ ÙŠØ¯ÙˆÙŠØ§Ù‹ Ù„Ù‚Ø·Ø§Ø¹ Ø§Ù„Ø¶ÙŠØ§ÙØ©.",
    },
    {
      id: "fru-banana",
      category: "fruits",
      unit: "kg",
      price: 24,
      nameEn: "Bananas",
      nameAr: "Ù…ÙˆØ²",
      descEn: "Rapid-transit bananas for maximum freshness.",
      descAr: "Ù…ÙˆØ² Ø¨Ù†Ù‚Ù„ Ø³Ø±ÙŠØ¹ Ù„Ù„Ø­ÙØ§Ø¸ Ø¹Ù„Ù‰ Ø§Ù„Ø·Ø²Ø§Ø¬Ø©.",
    },
    {
      id: "fru-strawberry",
      category: "fruits",
      unit: "kg",
      price: 55,
      nameEn: "Strawberries",
      nameAr: "ÙØ±Ø§ÙˆÙ„Ø©",
      descEn: "Premium seasonal strawberries.",
      descAr: "ÙØ±Ø§ÙˆÙ„Ø© Ù…ÙˆØ³Ù…ÙŠØ© ÙØ§Ø®Ø±Ø©.",
    },
    {
      id: "hot-linen",
      category: "hotel",
      unit: "set",
      price: 480,
      nameEn: "Luxury Linen Set",
      nameAr: "Ø·Ù‚Ù… Ù…ÙØ±ÙˆØ´Ø§Øª ÙØ§Ø®Ø±",
      descEn: "Hotel-grade linens and textiles.",
      descAr: "Ù…ÙØ±ÙˆØ´Ø§Øª ÙˆÙ…Ù†Ø³ÙˆØ¬Ø§Øª Ø¨Ø¯Ø±Ø¬Ø© ÙÙ†Ø¯Ù‚ÙŠØ©.",
    },
    {
      id: "hot-towel",
      category: "hotel",
      unit: "dozen",
      price: 260,
      nameEn: "Commercial Towels",
      nameAr: "Ù…Ù†Ø§Ø´Ù ØªØ¬Ø§Ø±ÙŠØ©",
      descEn: "Absorbency-tested towels for guest rooms.",
      descAr: "Ù…Ù†Ø§Ø´Ù Ù…Ø®ØªØ¨Ø±Ø© Ù„Ù„ØºØ±Ù Ø§Ù„ÙÙ†Ø¯Ù‚ÙŠØ©.",
    },
    {
      id: "hot-amenity",
      category: "hotel",
      unit: "kit",
      price: 95,
      nameEn: "Guest Amenities Kit",
      nameAr: "Ø·Ù‚Ù… Ù…Ø³ØªÙ„Ø²Ù…Ø§Øª Ø§Ù„Ù†Ø²ÙŠÙ„",
      descEn: "Premium guest amenities for hospitality.",
      descAr: "Ù…Ø³ØªÙ„Ø²Ù…Ø§Øª Ù†Ø²Ù„Ø§Ø¡ ÙØ§Ø®Ø±Ø© Ù„Ù„Ø¶ÙŠØ§ÙØ©.",
    },
    {
      id: "off-paper",
      category: "office",
      unit: "ream",
      price: 85,
      nameEn: "A4 Copy Paper",
      nameAr: "ÙˆØ±Ù‚ ØªØµÙˆÙŠØ± A4",
      descEn: "Bulk paper for daily office operations.",
      descAr: "ÙˆØ±Ù‚ Ø¨ÙƒÙ…ÙŠØ§Øª Ù„Ù„Ù…ÙƒØ§ØªØ¨ Ø§Ù„ÙŠÙˆÙ…ÙŠØ©.",
    },
    {
      id: "off-pen",
      category: "office",
      unit: "box",
      price: 45,
      nameEn: "Corporate Pens",
      nameAr: "Ø£Ù‚Ù„Ø§Ù… Ù…ÙƒØªØ¨ÙŠØ©",
      descEn: "Office stationery for administrative teams.",
      descAr: "Ù‚Ø±Ø·Ø§Ø³ÙŠØ© Ù…ÙƒØªØ¨ÙŠØ© Ù„Ù„ÙØ±Ù‚ Ø§Ù„Ø¥Ø¯Ø§Ø±ÙŠØ©.",
    },
    {
      id: "off-folder",
      category: "office",
      unit: "pack",
      price: 70,
      nameEn: "Filing Folders",
      nameAr: "Ù…Ù„ÙØ§Øª ØªÙ†Ø¸ÙŠÙ…",
      descEn: "Corporate filing and printing supplies.",
      descAr: "Ù…Ù„ÙØ§Øª ÙˆÙ…Ø³ØªÙ„Ø²Ù…Ø§Øª Ø·Ø¨Ø§Ø¹Ø© Ù„Ù„Ø´Ø±ÙƒØ§Øª.",
    },
    {
      id: "pkg-carton",
      category: "packaging",
      unit: "piece",
      price: 18,
      nameEn: "Heavy-duty Shipping Carton",
      nameAr: "ÙƒØ±ØªÙˆÙ† Ø´Ø­Ù† Ù‚ÙˆÙŠ",
      descEn: "Cartons tailored for corporate transport.",
      descAr: "ÙƒØ±Ø§ØªÙŠÙ† Ù…Ø®ØµØµØ© Ù„Ù„Ù†Ù‚Ù„ Ø§Ù„Ù…Ø¤Ø³Ø³ÙŠ.",
    },
    {
      id: "pkg-bubble",
      category: "packaging",
      unit: "roll",
      price: 120,
      nameEn: "Bubble Wrap Roll",
      nameAr: "Ø±ÙˆÙ„ ÙÙ‚Ø§Ø¹Ø§Øª Ø­Ù…Ø§ÙŠØ©",
      descEn: "Protective wrap and seals for cargo.",
      descAr: "ØªØºÙ„ÙŠÙ Ø­Ù…Ø§ÙŠØ© ÙˆØ£Ø®ØªØ§Ù… Ù„Ù„Ø´Ø­Ù†Ø§Øª.",
    },
    {
      id: "pkg-stretch",
      category: "packaging",
      unit: "roll",
      price: 150,
      nameEn: "Stretch Film",
      nameAr: "ÙÙŠÙ„Ù… ØªØºÙ„ÙŠÙ Ù…Ø·Ø§Ø·ÙŠ",
      descEn: "Secure wrapping for warehouse staging.",
      descAr: "ØªØºÙ„ÙŠÙ Ø¢Ù…Ù† Ù„ØªØ¬Ù‡ÙŠØ² Ø§Ù„Ù…Ø³ØªÙˆØ¯Ø¹Ø§Øª.",
    },
  ],
  requests: [],
  purchases: [],
  expenses: [],
  notifications: [],
  categories: [
    { id: "vegetables", en: "Fresh Vegetables", ar: "Ø§Ù„Ø®Ø¶Ø±ÙˆØ§Øª Ø§Ù„Ø·Ø§Ø²Ø¬Ø©", order: 1 },
    { id: "fruits", en: "Fresh Fruits", ar: "Ø§Ù„ÙØ§ÙƒÙ‡Ø© Ø§Ù„Ø·Ø§Ø²Ø¬Ø©", order: 2 },
    { id: "general", en: "General Goods", ar: "Ø¹Ø§Ù…", order: 3 },
    { id: "office", en: "Office Supplies", ar: "Ø§Ù„Ø£Ø¯ÙˆØ§Øª Ø§Ù„Ù…ÙƒØªØ¨ÙŠØ©", order: 4 },
    { id: "hotel", en: "Hotel Supplies", ar: "Ø£Ø¯ÙˆØ§Øª ÙÙ†Ø¯Ù‚ÙŠØ©", order: 5 },
    { id: "restaurant", en: "Restaurant Supplies", ar: "Ù„ÙˆØ§Ø²Ù… Ø§Ù„Ù…Ø·Ø§Ø¹Ù…", order: 6 },
    { id: "appliances", en: "Appliances", ar: "Ø£Ø¬Ù‡Ø²Ø©", order: 7 },
    { id: "packaging", en: "Packaging & Wrapping Materials", ar: "Ù…ÙˆØ§Ø¯ Ø§Ù„ØªØ¹Ø¨Ø¦Ø© ÙˆØ§Ù„ØªØºÙ„ÙŠÙ", order: 8 },
  ],
  users: [
    {
      id: "u-admin",
      name: "Gosst Admin",
      email: "info@gossts.com",
      password: SEED_ADMIN_PASSWORD,
      role: "super",
      permissions: [...DEFAULT_PERMISSIONS.super],
    },
  ],
};

function withDefaultCost(p) {
  if (p.costPrice == null && p.price != null && !Number.isNaN(Number(p.price))) {
    p.costPrice = Math.round(Number(p.price) * 0.75 * 100) / 100;
  }
  return p;
}

function loadDb() {
  let db;
  if (!fs.existsSync(dbPath)) {
    fs.writeFileSync(dbPath, JSON.stringify(seed, null, 2));
    const seededFromEnv = !!(process.env.GOSS_ADMIN_PASSWORD || process.env.ADMIN_PASSWORD);
    console.log(
      `[BOOT] Fresh database created with super admin '${seed.users[0].email}'.` +
        (seededFromEnv
          ? " Administrator password taken from the environment."
          : " One-time generated password, change it after first login.")
    );
    db = structuredClone(seed);
  } else {
    db = JSON.parse(fs.readFileSync(dbPath, "utf8").replace(/^\uFEFF/, ""));
  }
  if (Array.isArray(db.products)) db.products = db.products.map(withDefaultCost);
  // migrate old users to role-based permissions
  const users = db.users || [];
  for (const u of users) {
    if (u.id === "u-admin") {
      u.role = "super";
      u.permissions = [...DEFAULT_PERMISSIONS.super];
      continue;
    }
    if (!Array.isArray(u.permissions) || u.permissions.length === 0) {
      u.role = TEAM_ROLES.includes(u.role) ? u.role : "admin";
      u.permissions = [...(DEFAULT_PERMISSIONS[u.role] || DEFAULT_PERMISSIONS.admin)];
    }
    // admins manage the team: grant them the team panel
    if (u.role === "admin" && !u.permissions.includes("team")) {
      u.permissions.push("team");
    }
  }
  // Migrate legacy plaintext passwords to scrypt hashes (credentials unchanged).
  let dirty = false;
  for (const u of users) {
    if (u.password && !u.password.startsWith("scrypt$")) {
      u.password = hashPassword(u.password);
      dirty = true;
    }
  }
  // Assign stable order numbers to requests that predate them (kept once set).
  if (Array.isArray(db.requests)) {
    let maxOrder = 0;
    for (const r of db.requests) {
      const n = Number(r.orderNo);
      if (Number.isFinite(n) && n > 0 && n > maxOrder) maxOrder = n;
    }
    for (const r of db.requests) {
      const n = Number(r.orderNo);
      if (!Number.isFinite(n) || n <= 0) {
        r.orderNo = ++maxOrder;
        dirty = true;
      }
    }
  }
  if (dirty) saveDb(db);
  return db;
}

function saveDb(db) {
  fs.writeFileSync(dbPath, JSON.stringify(db, null, 2));
}

function auth(req, res, next) {
  const user = sessionUser(bearerToken(req.headers.authorization));
  if (!user) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  req.user = user;
  next();
}

// Requires the authenticated user to hold at least one of the given
// permission keys (see DEFAULT_PERMISSIONS above).
function requirePerm(...perms) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: "Unauthorized" });
    if (!perms.some((p) => req.user.permissions.includes(p))) {
      return res.status(403).json({ error: "Forbidden" });
    }
    next();
  };
}

// Requires the authenticated user to have one of the given roles.
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: "Unauthorized" });
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Forbidden" });
    }
    next();
  };
}

// --- Firebase Cloud Messaging (push) ---------------------------------------
// Enabled at runtime when a service-account credential is available
// (GOOGLE_APPLICATION_CREDENTIALS). Without it, notify endpoints respond 503
// and the app silently falls back to in-app stream updates.

let fcmDb = null;
let fcmMessaging = null;
let fcmAuth = null;
let fcmProm = null;

async function initFcm() {
  if (fcmMessaging) return true;
  // Only touch the Firebase Admin SDK when real credentials are configured.
  const cred = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!cred || !fs.existsSync(cred)) return false;
  if (!fcmProm) {
    fcmProm = (async () => {
      try {
        const app = initializeApp({
          projectId: "gosst-9c2c6",
          credential: applicationDefault(),
        });
        // force eager discovery of credentials so failures surface here (inside
        // try/catch) instead of as an unhandled rejection that crashes the process
        await getFirestore(app).collection("init_probe").limit(1).get().catch(() => {});
        fcmDb = getFirestore(app);
        fcmMessaging = getMessaging(app);
        fcmAuth = getAuth(app);
        return true;
      } catch (e) {
        console.error("FCM unavailable:", e.message);
        return false;
      }
    })();
  }
  return fcmProm;
}

async function fetchTokens(collection) {
  const snap = await fcmDb.collection(collection).get();
  const tokens = [];
  snap.forEach((d) => {
    const t = d.data().token;
    if (t) tokens.push(t);
  });
  return tokens;
}

async function sendPush(tokens, title, body, data = {}) {
  if (!tokens.length) return { sent: 0 };
  const messages = tokens.map((token) => ({
    token,
    notification: { title, body },
    data,
  }));
  const res = await fcmMessaging.sendEach(messages);
  return { sent: res.successCount, failed: res.failureCount };
}

const app = express();
// Restrict browser-origin access to trusted local dev hosts. Native clients
// (mobile HTTP, no Origin header) are unaffected, as is the bundled web app
// served same-origin from /dist.
function allowedOrigin(origin) {
  if (!origin) return true;
  if (origin === "null") return true; // file:// pages during local development
  try {
    const o = new URL(origin);
    return o.hostname === "localhost" || o.hostname === "127.0.0.1";
  } catch {
    return false;
  }
}
app.disable("x-powered-by");
app.use(cors({ origin: (origin, cb) => cb(null, allowedOrigin(origin)) }));
app.use(express.json({ limit: "1mb" }));
app.use(basicSecurity);
app.use("/api", rateLimit);
app.use(guardFieldLengths);

// minimal request logging to observe app traffic during local testing
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  next();
});

app.get("/api/products", (req, res) => {
  const products = loadDb().products || [];
  // The customer-facing catalog must not expose the shop's cost price.
  // Only authenticated team members receive the full product data.
  if (sessionUser(bearerToken(req.headers.authorization))) {
    return res.json(products);
  }
  return res.json(products.map(({ costPrice, ...pub }) => ({ ...pub })));
});

app.get("/api/categories", (_req, res) => {
  const db = loadDb();
  if (!db.categories) db.categories = [];
  res.json(db.categories);
});

app.post("/api/categories", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  if (!db.categories) db.categories = [];
  const { id, en, ar } = req.body || {};
  if (!id || !en) return res.status(400).json({ error: "Missing details" });
  if (db.categories.some((c) => c.id === id)) {
    return res.status(409).json({ error: "Category already exists" });
  }
  const category = {
    id,
    en,
    ar: ar || en,
    order: db.categories.length + 1,
  };
  db.categories.push(category);
  saveDb(db);
  res.status(201).json(category);
});

// Logout revokes ONLY the caller's own session. It never clears the whole
// session map, so a stolen token can only ever kill its own session.
app.post("/api/logout", (req, res) => {
  const token = bearerToken(req.headers.authorization);
  if (token && sessions.has(token)) {
    sessions.delete(token);
    return res.json({ ok: true, clearedSessions: 1 });
  }
  return res.status(401).json({ error: "Unauthorized" });
});

app.post("/api/login", (req, res) => {
  const { email, password } = req.body || {};
  const ip = clientIp(req);
  const blockUntil = loginBlocked(ip, email);
  if (blockUntil) {
    const waitSec = Math.ceil((blockUntil - Date.now()) / 1000);
    return res.status(429).json({
      error: "Too many failed attempts. Try again in a few minutes.",
      retryAfter: waitSec,
    });
  }
  // Legacy: single master password only, and only when ADMIN_PASSWORD is set
  // in the environment. When it is missing this path is disabled entirely —
  // it must never grant a session.
  if (!email && ADMIN_PASSWORD && password === ADMIN_PASSWORD) {
    clearLoginFailures(ip, email);
    return res.json({
      token: issueSession({ id: "root", name: "Owner", email: "", role: "super", permissions: [...DEFAULT_PERMISSIONS.super] }),
    });
  }
  const users = (loadDb().users || []);
  const user = users.find(
    (u) => u.email === (email || "").toLowerCase() && verifyPassword(password, u.password)
  );
  if (!user) {
    // Equalize the response time with the success path so the endpoint cannot
    // be used to enumerate which accounts exist.
    verifyPassword(password, hashPassword("timing-normalize-dummy"));
    logFailure(ip, email);
    const attempts = loginAttempts.get(abuseKey(ip, email));
    return res.status(401).json({
      error: "Invalid email or password",
      attemptsRemaining: Math.max(0, LOGIN_FAIL_MAX - (attempts ? attempts.count : 1)),
    });
  }
  clearLoginFailures(ip, email);
  // The server - not the client - decides the member's role and permissions,
  // so a delegate can never request an "admin" sign-in and an admin always
  // lands on their real panels. The app uses these as the source of truth.
  res.json({
    token: issueSession(user),
    user: publicUser(user),
  });
});

app.post("/api/register", (req, res) => {
  const { name, email, password, code } = req.body || {};
  const ip = clientIp(req);
  const blockUntil = loginBlocked(ip, email);
  if (blockUntil) {
    const waitSec = Math.ceil((blockUntil - Date.now()) / 1000);
    return res.status(429).json({ error: "Too many attempts", retryAfter: waitSec });
  }
  if (!ADMIN_PASSWORD || code !== ADMIN_PASSWORD) {
    logFailure(ip, email);
    return res.status(401).json({ error: "Invalid registration code" });
  }
  if (!name || !email || !password) {
    return res.status(400).json({ error: "Missing details" });
  }
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LEN) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LEN} characters` });
  }
  const db = loadDb();
  if (!db.users) db.users = [];
  if (db.users.some((u) => u.email === email.toLowerCase())) {
    return res.status(409).json({ error: "Email already registered" });
  }
  clearLoginFailures(ip, email);
  const user = {
    id: newId("u"),
    name,
    email: email.toLowerCase(),
    password: hashPassword(password),
    role: "admin",
    permissions: [...DEFAULT_PERMISSIONS.admin],
  };
  db.users.push(user);
  saveDb(db);
  res.status(201).json({ id: user.id });
});

app.post("/api/change-password", auth, (req, res) => {
  const { email, oldPassword, newPassword } = req.body || {};
  // Only an authenticated session may rotate ITS OWN password, and the body
  // must not point at another account.
  if (email && email.toLowerCase() !== req.user.email) {
    return res.status(403).json({ error: "Forbidden" });
  }
  const ip = clientIp(req);
  if (loginBlocked(ip, email)) {
    return res.status(429).json({ error: "Too many attempts. Try again later." });
  }
  if (typeof newPassword !== "string" || newPassword.length < MIN_PASSWORD_LEN) {
    return res.status(400).json({ error: `New password must be at least ${MIN_PASSWORD_LEN} characters` });
  }
  const db = loadDb();
  const user = (db.users || []).find(
    (u) => u.id === req.user.id && verifyPassword(oldPassword, u.password)
  );
  if (!user) {
    logFailure(ip, email);
    return res.status(401).json({ error: "Invalid credentials" });
  }
  clearLoginFailures(ip, email);
  user.password = hashPassword(newPassword);
  saveDb(db);
  // Every OTHER live session for this account is revoked on a password change,
  // so a leaked token dies the moment the owner rotates their password.
  const currentToken = bearerToken(req.headers.authorization);
  for (const [tok, s] of sessions) {
    if (s.email === user.email && tok !== currentToken) sessions.delete(tok);
  }
  res.json({ ok: true });
});

function publicUser(u) {
  return { id: u.id, name: u.name, email: u.email, role: u.role, permissions: u.permissions || [] };
}

app.get("/api/admins", auth, requirePerm("team"), (_req, res) => {
  res.json((loadDb().users || []).filter((u) => TEAM_ROLES.includes(u.role)).map(publicUser));
});

app.post("/api/admins", auth, requirePerm("team"), (req, res) => {
  const { name, email, password, role, permissions } = req.body || {};
  if (!name || !email || !password) {
    return res.status(400).json({ error: "Missing details" });
  }
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LEN) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LEN} characters` });
  }
  const userRole = TEAM_ROLES.includes(role) ? role : "admin";
  let perms = Array.isArray(permissions) && permissions.length > 0
    ? permissions.filter((p) => PERMISSION_KEYS.includes(p))
    : [...DEFAULT_PERMISSIONS[userRole]];
  if (userRole === "admin" && !perms.includes("team")) perms.push("team");
  if (userRole !== "admin") perms = perms.filter((p) => p !== "team");
  const db = loadDb();
  if (!db.users) db.users = [];
  if (db.users.some((u) => u.email === email.toLowerCase())) {
    return res.status(409).json({ error: "Email already registered" });
  }
  const user = {
    id: newId("u"),
    name,
    email: email.toLowerCase(),
    password: hashPassword(password),
    role: userRole,
    permissions: perms,
  };
  db.users.push(user);
  saveDb(db);
  res.status(201).json(publicUser(user));
});

app.patch("/api/admins/:id", auth, requirePerm("team"), (req, res) => {
  const db = loadDb();
  const i = (db.users || []).findIndex((u) => u.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  const { role, permissions } = req.body || {};
  const target = db.users[i];
  if (target.id === "u-admin") return res.status(403).json({ error: "Cannot change the owner" });
  if (target.role === "super") return res.status(403).json({ error: "Cannot change a super admin" });
  const nextRole = TEAM_ROLES.includes(role) ? role : target.role;
  let perms = Array.isArray(permissions)
    ? permissions.filter((p) => PERMISSION_KEYS.includes(p))
    : [...(DEFAULT_PERMISSIONS[nextRole] || [])];
  if (nextRole === "admin" && !perms.includes("team")) perms.push("team");
  if (nextRole !== "admin") perms = perms.filter((p) => p !== "team");
  target.role = nextRole;
  target.permissions = perms;
  saveDb(db);
  res.json(publicUser(target));
});

app.delete("/api/admins/:id", auth, requirePerm("team"), (req, res) => {
  const db = loadDb();
  const i = (db.users || []).findIndex((u) => u.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  const target = db.users[i];
  if (target.id === "u-admin") return res.status(403).json({ error: "Cannot remove the owner" });
  if (target.role === "super") return res.status(403).json({ error: "Cannot remove a super admin" });
  db.users.splice(i, 1);
  saveDb(db);
  // Revoke every live session owned by the removed member so a deleted
  // account cannot keep using its previously-issued token.
  for (const [tok, s] of sessions) {
    if (s.id === target.id) sessions.delete(tok);
  }
  res.json({ ok: true });
});

// Hard-deletes a Firebase Authentication user so a removed team member can
// never sign back in with the old email/password. Requires the Admin SDK to
// be configured (GOOGLE_APPLICATION_CREDENTIALS) — otherwise returns 503 and
// the app removes the Firestore document anyway (defense in depth).
app.post("/api/firestore/delete-auth-user", (req, res) => {
  const uid = (req.body || {}).uid;
  if (typeof uid !== "string" || !uid) {
    return res.status(400).json({ error: "Missing uid" });
  }
  if (!fcmAuth) {
    return res.status(503).json({
      error: "Admin SDK not configured; set GOOGLE_APPLICATION_CREDENTIALS",
    });
  }
  (async () => {
    try {
      await fcmAuth.deleteUser(uid);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: e.message || "Delete failed" });
    }
  })();
});

app.post("/api/products", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const product = {
    id: newId("p"),
    category: req.body.category || "office",
    unit: req.body.unit || "unit",
    price: Number(req.body.price) || 0,
    costPrice: Number(req.body.costPrice) || Math.round(Number(req.body.price) * 0.75 * 100) / 100,
    stock: Number(req.body.stock) || 0,
    nameEn: req.body.nameEn || "",
    nameAr: req.body.nameAr || "",
    descEn: req.body.descEn || "",
    descAr: req.body.descAr || "",
  };
  db.products.push(product);
  saveDb(db);
  res.status(201).json(product);
});

const PRODUCT_FIELDS = ["category", "unit", "price", "costPrice", "stock", "nameEn", "nameAr", "descEn", "descAr"];

app.put("/api/products/:id", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const i = db.products.findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  const updated = { ...db.products[i], id: db.products[i].id };
  for (const key of PRODUCT_FIELDS) {
    if (typeof req.body[key] !== "undefined") {
      updated[key] = (key === "price" || key === "costPrice" || key === "stock") ? Number(req.body[key]) : req.body[key];
    }
  }
  db.products[i] = updated;
  saveDb(db);
  res.json(db.products[i]);
});

app.delete("/api/products/:id", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const i = db.products.findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.products.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

// Bulk Excel import: upserts the categories and products parsed from the
// uploaded sheet (admin only). Matches the payload the app sends after it
// parses the file client-side.
app.post("/api/products/import", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  if (!db.categories) db.categories = [];
  if (!db.products) db.products = [];
  const { categories, products } = req.body || {};
  if ((Array.isArray(categories) && categories.length > MAX_IMPORT_ROWS) ||
      (Array.isArray(products) && products.length > MAX_IMPORT_ROWS)) {
    return res.status(400).json({ error: `Import is limited to ${MAX_IMPORT_ROWS} rows per sheet` });
  }
  let categoriesCreated = 0;
  let productsCreated = 0;
  let productsUpdated = 0;
  if (Array.isArray(categories)) {
    for (const c of categories) {
      const id = String(c.id || "");
      if (!id) continue;
      const existing = db.categories.find((x) => x.id === id);
      const rec = { id, en: c.en || "", ar: c.ar || c.en || "", order: db.categories.length + 1 };
      if (existing) {
        existing.en = rec.en;
        existing.ar = rec.ar;
      } else {
        db.categories.push(rec);
        categoriesCreated++;
      }
    }
  }
  if (Array.isArray(products)) {
    for (const p of products) {
      const id = String(p.id || "");
      if (!id) continue;
      const price = Number(p.price) || 0;
      const rec = {
        id,
        category: p.category || "office",
        unit: p.unit || "unit",
        price,
        costPrice: Number(p.costPrice) || Math.round(price * 0.75 * 100) / 100,
        stock: Number(p.stock) || 0,
        nameEn: p.nameEn || "",
        nameAr: p.nameAr || "",
        descEn: p.descEn || "",
        descAr: p.descAr || "",
      };
      const i = db.products.findIndex((x) => x.id === id);
      if (i >= 0) {
        db.products[i] = { ...db.products[i], ...rec, id };
        productsUpdated++;
      } else {
        db.products.push(rec);
        productsCreated++;
      }
    }
  }
  saveDb(db);
  res.status(201).json({ ok: true, categoriesCreated, productsCreated, productsUpdated });
});

app.get("/api/requests", auth, requirePerm("requests"), (_req, res) => {
  res.json(loadDb().requests);
});

app.post("/api/requests", (req, res) => {
  const { company, name, phone, email, notes, items, customerId, origin, destination, type } = req.body || {};
  if (!name || !phone || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "Missing request details" });
  }
  if (items.length > MAX_REQUEST_ITEMS) {
    return res.status(400).json({ error: `A request is limited to ${MAX_REQUEST_ITEMS} items` });
  }
  const db = loadDb();
  let maxOrder = 0;
  for (const r of (db.requests || [])) {
    const n = Number(r.orderNo);
    if (Number.isFinite(n) && n > 0 && n > maxOrder) maxOrder = n;
  }
  const request = {
    id: newId("r"),
    orderNo: maxOrder + 1,
    createdAt: new Date().toISOString(),
    status: "new",
    company: company || "",
    name,
    phone,
    email: email || "",
    notes: notes || "",
    items,
    customerId: typeof customerId === "string" ? customerId : "",
    origin: typeof origin === "string" ? origin : "",
    destination: typeof destination === "string" ? destination : "",
    type: type === "quote" ? "quote" : "supply",
  };
  db.requests.unshift(request);
  saveDb(db);
  notifyAdminsNewRequest(name, Array.isArray(items) ? items.length : 0).catch(() => {});
  res.status(201).json(request);
});

// Customer-scoped: the caller must prove possession of the device id by
// echoing it in the X-Customer-Id header as well as the query, so a third
// party cannot harvest every customer's requests by iterating customerId.
app.get("/api/requests/mine", (req, res) => {
  const cid = String(req.query.customerId || "");
  const headerCid = String(req.get("x-customer-id") || "");
  if (!cid || cid !== headerCid || Array.isArray(req.query.customerId)) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  const all = (loadDb().requests || []).filter((r) => r.customerId === cid);
  res.json(all);
});

async function pushStatusUpdate(request, status) {
  if (!(await initFcm()) || !request || !request.customerId) return;
  try {
    const label = STATUS_LABELS[status] || STATUS_LABELS.fresh;
    const body = status === "accepted"
      ? `${request.name} Â· ${label.en} â€” delivery within 48 hours from acceptance.`
      : `${request.name} Â· ${label.en}`;
    const tokens = await fcmDb.collection("customer_tokens").doc(request.customerId).get().then((d) =>
      d.exists && d.data().token ? [d.data().token] : []
    );
    await sendPush(
      tokens,
      `GOSST \u2014 ${label.ar}`,
      body,
      { type: "request_status", status }
    );
  } catch (e) {
    console.error("pushStatusUpdate failed:", e.message);
  }
}

// Request statuses used by the app (see RequestStatus in lib/models/models.dart).
const REQUEST_STATUSES = new Set([
  "new", "accepted", "preparing", "arriving", "delivering", "delivered", "confirmed", "rejected",
]);

app.patch("/api/requests/:id", auth, requirePerm("requests"), async (req, res) => {
  const db = loadDb();
  const i = db.requests.findIndex((r) => r.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  if (req.body.status !== undefined && !REQUEST_STATUSES.has(req.body.status)) {
    return res.status(400).json({ error: "Unknown status" });
  }
  const prev = db.requests[i].status;
  db.requests[i].status = req.body.status || prev;
  saveDb(db);
  if (db.requests[i].status !== prev) {
    await pushStatusUpdate(db.requests[i], db.requests[i].status);
  }
  res.json(db.requests[i]);
});

app.delete("/api/requests/:id", auth, requirePerm("requests"), (req, res) => {
  const db = loadDb();
  const i = db.requests.findIndex((r) => r.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.requests.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

// Customer accepts the delivery (verifies ownership via customerId).
// Only allowed while the order is out for delivery ('delivering').
app.post("/api/requests/:id/confirm", async (req, res) => {
  const { customerId } = req.body || {};
  const db = loadDb();
  const i = db.requests.findIndex((r) => r.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  if (!db.requests[i].customerId || db.requests[i].customerId !== customerId) {
    return res.status(403).json({ error: "Not your request" });
  }
  if (db.requests[i].status === "delivering") {
    db.requests[i].status = "confirmed";
    saveDb(db);
  }
  // notify all admin devices that the goods were delivered (only on change)
  if (db.requests[i].status === "confirmed" && await initFcm()) {
    try {
      const tokens = await fetchTokens("admin_tokens");
      await sendPush(
        tokens,
        `GOSST \u2014 \u062a\u0645 \u062a\u0633\u0644\u064a\u0645 \u0627\u0644\u0628\u0636\u0627\u0639\u0629`,
        `${db.requests[i].name} accepted the delivery (${db.requests[i].id})`,
        { type: "request_status", status: "delivered", requestId: db.requests[i].id }
      );
    } catch (e) {
      console.error("accept push failed:", e.message);
    }
  }
  res.json(db.requests[i]);
});

// Customer rejects the delivery (verifies ownership via customerId).
app.post("/api/requests/:id/reject", async (req, res) => {
  const { customerId } = req.body || {};
  const db = loadDb();
  const i = db.requests.findIndex((r) => r.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  if (!db.requests[i].customerId || db.requests[i].customerId !== customerId) {
    return res.status(403).json({ error: "Not your request" });
  }
  if (db.requests[i].status === "delivering") {
    db.requests[i].status = "rejected";
    saveDb(db);
  }
  if (db.requests[i].status === "rejected" && await initFcm()) {
    try {
      const tokens = await fetchTokens("admin_tokens");
      await sendPush(
        tokens,
        `GOSST \u2014 \u0631\u0641\u0636 \u0627\u0644\u062a\u0633\u0644\u064a\u0645`,
        `${db.requests[i].name} rejected the delivery (${db.requests[i].id})`,
        { type: "request_status", status: "rejected", requestId: db.requests[i].id }
      );
    } catch (e) {
      console.error("reject push failed:", e.message);
    }
  }
  res.json(db.requests[i]);
});

// Purchases (cost tracking)
app.get("/api/purchases", auth, requirePerm("purchases"), (_req, res) => {
  res.json((loadDb().purchases || []).reverse());
});

app.post("/api/purchases", auth, requirePerm("purchases"), (req, res) => {
  const db = loadDb();
  const qty = Number(req.body.qty) || 0;
  const costPrice = Number(req.body.costPrice) || 0;
  const vat = Number(req.body.vat) || 0;
  const purchase = {
    id: newId("pu"),
    date: new Date().toISOString(),
    supplier: req.body.supplier || "",
    productId: req.body.productId || "",
    qty,
    costPrice,
    vat,
    total: qty * costPrice + vat,
  };
  if (!db.purchases) db.purchases = [];
  db.purchases.unshift(purchase);
  saveDb(db);
  res.status(201).json(purchase);
});

app.delete("/api/purchases/:id", auth, requirePerm("purchases"), (req, res) => {
  const db = loadDb();
  const i = (db.purchases || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.purchases.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

const PURCHASE_FIELDS = ["supplier", "productId", "qty", "costPrice", "vat"];

app.patch("/api/purchases/:id", auth, requirePerm("purchases"), (req, res) => {
  const db = loadDb();
  const i = (db.purchases || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  for (const key of PURCHASE_FIELDS) {
    if (typeof req.body[key] === "undefined") continue;
    if (key === "qty") db.purchases[i].qty = Math.max(0, Number(req.body[key]) || 0);
    else if (key === "costPrice") db.purchases[i].costPrice = Number(req.body[key]) || 0;
    else if (key === "vat") db.purchases[i].vat = Number(req.body[key]) || 0;
    else db.purchases[i][key] = req.body[key];
  }
  db.purchases[i].total = db.purchases[i].qty * db.purchases[i].costPrice + (db.purchases[i].vat || 0);
  saveDb(db);
  res.json(db.purchases[i]);
});

// Expenses
app.get("/api/expenses", auth, requirePerm("expenses"), (_req, res) => {
  res.json((loadDb().expenses || []).reverse());
});

app.post("/api/expenses", auth, requirePerm("expenses"), (req, res) => {
  const db = loadDb();
  const expense = {
    id: newId("ex"),
    date: req.body.date || new Date().toISOString(),
    category: req.body.category || "General",
    description: req.body.description || "",
    amount: Number(req.body.amount) || 0,
  };
  if (!db.expenses) db.expenses = [];
  db.expenses.unshift(expense);
  saveDb(db);
  res.status(201).json(expense);
});

app.delete("/api/expenses/:id", auth, requirePerm("expenses"), (req, res) => {
  const db = loadDb();
  const i = (db.expenses || []).findIndex((e) => e.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.expenses.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

const PAYMENT_FIELDS = ["requestId", "customerId", "company", "name", "date", "method", "note"];

// Double-entry journal (finance only: super/admin, same as the Firestore rule)
function sanitizeJournalLine(l) {
  const amount = Number(l && l.amount) || 0;
  return {
    accountCode: (l && l.accountCode) || "",
    accountEn: (l && l.accountEn) || "",
    accountAr: (l && l.accountAr) || "",
    amount,
  };
}

app.get("/api/journal", auth, requireRole("super", "admin"), (_req, res) => {
  res.json((loadDb().journal || []).reverse());
});

app.post("/api/journal", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const debits = Array.isArray(req.body.debits) ? req.body.debits : [];
  const credits = Array.isArray(req.body.credits) ? req.body.credits : [];
  if (debits.length > MAX_JOURNAL_LINES || credits.length > MAX_JOURNAL_LINES) {
    return res.status(400).json({ error: `Journal entries are limited to ${MAX_JOURNAL_LINES} lines` });
  }
  const entry = {
    id: newId("j"),
    date: req.body.date || new Date().toISOString(),
    memo: req.body.memo || "",
    debits: debits.map(sanitizeJournalLine),
    credits: credits.map(sanitizeJournalLine),
    createdAt: new Date().toISOString(),
  };
  if (!db.journal) db.journal = [];
  db.journal.unshift(entry);
  saveDb(db);
  res.status(201).json(entry);
});

app.delete("/api/journal/:id", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const i = (db.journal || []).findIndex((e) => e.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.journal.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

app.get("/api/payments", auth, requireRole("super", "admin"), (_req, res) => {
  res.json((loadDb().payments || []).reverse());
});

app.post("/api/payments", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const payment = {
    id: newId("py"),
    requestId: req.body.requestId || "",
    customerId: req.body.customerId || "",
    company: req.body.company || "",
    name: req.body.name || "",
    date: req.body.date || new Date().toISOString(),
    amount: Number(req.body.amount) || 0,
    method: req.body.method || "cash",
    note: req.body.note || "",
    createdAt: new Date().toISOString(),
  };
  if (!db.payments) db.payments = [];
  db.payments.unshift(payment);
  saveDb(db);
  res.status(201).json(payment);
});

app.delete("/api/payments/:id", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const i = (db.payments || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.payments.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

app.patch("/api/payments/:id", auth, requireRole("super", "admin"), (req, res) => {
  const db = loadDb();
  const i = (db.payments || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  for (const key of PAYMENT_FIELDS) {
    if (typeof req.body[key] === "undefined") continue;
    if (key === "amount") db.payments[i].amount = Number(req.body[key]) || 0;
    else db.payments[i][key] = req.body[key];
  }
  saveDb(db);
  res.json(db.payments[i]);
});

const EXPENSE_FIELDS = ["date", "category", "description", "amount"];

app.patch("/api/expenses/:id", auth, requirePerm("expenses"), (req, res) => {
  const db = loadDb();
  const i = (db.expenses || []).findIndex((e) => e.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  for (const key of EXPENSE_FIELDS) {
    if (typeof req.body[key] === "undefined") continue;
    if (key === "amount") db.expenses[i].amount = Number(req.body[key]) || 0;
    else db.expenses[i][key] = req.body[key];
  }
  saveDb(db);
  res.json(db.expenses[i]);
});

// Price quote notifications (sent to customers when admin edits a price)
app.get("/api/notifications", (_req, res) => {
  res.json(loadDb().notifications || []);
});

// Best-effort push to admin devices after a customer submits a request.
// Runs server-side so nothing can trigger pushes anonymously. Only sends
// when FCM is configured (returns 503 otherwise).
async function notifyAdminsNewRequest(name, itemsCount) {
  if (!(await initFcm())) return;
  try {
    const tokens = await fetchTokens("admin_tokens");
    await sendPush(
      tokens,
      "GOSST \u2014 New request",
      `${name || "A customer"} sent a request (${itemsCount || 0} items)`,
      { type: "new_request" }
    );
  } catch (e) {
    console.error("notifyAdminsNewRequest failed:", e.message);
  }
}

// External push: admin updated a price -> all customer devices (admin only)
app.post("/api/notify/price-update", auth, requireRole("super", "admin"), async (req, res) => {
  if (!(await initFcm())) return res.status(503).json({ error: "FCM not configured" });
  try {
    const { productNameEn, productNameAr, oldPrice, newPrice, unit } = req.body || {};
    const tokens = await fetchTokens("customer_tokens");
    const result = await sendPush(
      tokens,
      "GOSST \u2014 Price updated",
      `${productNameEn || "Product"} ${oldPrice} -> ${newPrice} ${unit || ""}`
        .trim(),
      { type: "price_update" }
    );
    res.json({ ok: true, ...result });
  } catch (e) {
    console.error("notify/price-update failed:", e.message);
    res.status(500).json({ ok: false, error: "Push failed" });
  }
});

app.post("/api/notifications", auth, requirePerm("quotes"), (req, res) => {
  const db = loadDb();
  if (!db.notifications) db.notifications = [];
  const notification = {
    id: newId("n"),
    productId: req.body.productId || "",
    productNameEn: req.body.productNameEn || "",
    productNameAr: req.body.productNameAr || "",
    oldPrice: Number(req.body.oldPrice) || 0,
    newPrice: Number(req.body.newPrice) || 0,
    unit: req.body.unit || "",
    createdAt: new Date().toISOString(),
  };
  db.notifications.unshift(notification);
  saveDb(db);
  res.status(201).json(notification);
});

// JSON 404 for unknown API routes (the SPA fallback below must never swallow them).
app.use("/api", (_req, res) => res.status(404).json({ error: "Not found" }));

// Centralized error handler: never leak stack traces or internals to clients.
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

const dist = path.join(__dirname, "..", "dist");
if (fs.existsSync(dist)) {
  app.use(express.static(dist));
  app.get("*", (_req, res) => res.sendFile(path.join(dist, "index.html")));
}app.listen(4000, process.env.GOSS_HOST || "127.0.0.1", () => {
  console.log("GOSST API on http://127.0.0.1:4000");
});

// --- Firestore-watcher pushes ----------------------------------------------
// The app writes its live data straight to Firestore (cloud mode), so the HTTP
// CRUD endpoints never see most requests/messages. To keep external push
// notifications working in all cases, the server watches Firestore and sends
// FCM pushes when a service-account credential is configured. Auto-activates:
// without credentials the watchers stay off and the app still pops local
// notifications itself (NotificationWatcher).

const watcherSeen = new Set(); // "req:<id>:<status>" / "msg:<id>"
const WATCHER_SEEN_MAX = 20000;

function markSeen(key) {
  if (watcherSeen.size >= WATCHER_SEEN_MAX) watcherSeen.clear();
  watcherSeen.add(key);
  return key;
}

let pushWatchersStarted = false;

function firestoreTimeToMs(v) {
  if (!v) return 0;
  if (v.seconds != null) return Number(v.seconds) * 1000;
  if (v._seconds != null) return Number(v._seconds) * 1000;
  const t = Date.parse(String(v));
  return Number.isFinite(t) ? t : 0;
}

async function pushChatMessage(d, msgId) {
  const convId = (d && d.conversationId) || "";
  const senderRole = (d && d.senderRole) || "";
  if (!convId || !senderRole) return;
  const convSnap = await fcmDb
    .collection("chat_conversations")
    .doc(convId)
    .get()
    .catch(() => null);
  if (!convSnap || !convSnap.exists) return;
  const conv = convSnap.data() || {};
  try {
    const payload = {
      type: "chat",
      conversationId: convId,
      senderRole,
      conversationStatus: String(conv.status || ""),
    };
    if (senderRole === "customer") {
      // A customer writes -> every admin device should know.
      const tokens = await fetchTokens("admin_tokens");
      await sendPush(
        tokens,
        "GOSST \u2014 \u0645\u062d\u0627\u062f\u062b\u0629 \u0627\u0644\u062f\u0639\u0645 / Support chat",
        "New message from a customer. / \u0631\u0633\u0627\u0644\u0629 \u062c\u062f\u064a\u062f\u0629 \u0645\u0646 \u0627\u0644\u0639\u0645\u064a\u0644.",
        payload
      );
    } else if (senderRole === "admin") {
      // An admin writes -> only the conversation owner (customer) is notified.
      const cid = (conv.customerId || "").toString();
      if (!cid) return;
      const tok = await fcmDb
        .collection("customer_tokens")
        .doc(cid)
        .get()
        .then((x) => (x.exists ? x.data().token : ""))
        .catch(() => "");
      if (!tok) return;
      await sendPush(
        [tok],
        "GOSST \u2014 \u0645\u062d\u0627\u062f\u062b\u0629 \u0627\u0644\u062f\u0639\u0645 / Support chat",
        "New message from the support team. / \u0631\u0633\u0627\u0644\u0629 \u062c\u062f\u064a\u062f\u0629 \u0645\u0646 \u0641\u0631\u064a\u0642 \u0627\u0644\u062f\u0639\u0645.",
        payload
      );
    }
  } catch (e) {
    console.error("pushChatMessage failed:", e.message);
  }
  void msgId;
}

async function startPushWatchers() {
  if (!(await initFcm())) return false;
  if (pushWatchersStarted) return true;
  pushWatchersStarted = true;
  const bootMs = Date.now();

  // (1) New request -> all admin devices (fresh documents created after boot).
  fcmDb
    .collection("requests")
    .onSnapshot((snap) => {
      try {
        snap.docChanges().forEach((ch) => {
          if (ch.type !== "added") return;
          const d = ch.doc.data();
          const createdAtMs = firestoreTimeToMs(d && d.createdAt);
          if (createdAtMs && createdAtMs < bootMs) return; // pre-boot history
          const st = d && d.status;
          if (st !== "new" && st !== "fresh") return;
          const key = `req:${ch.doc.id}:new`;
          if (watcherSeen.has(key)) return;
          markSeen(key);
          const job = Promise.resolve(
            notifyAdminsNewRequest((d && d.name) || "A customer", (d && d.items || []).length)
          );
          job.catch(() => {});
        });
      } catch (e) {
        console.error("[PUSH] requests watcher error:", e.message);
      }
    });

  // (2) Request status changed -> the owning customer device(s).
  fcmDb
    .collection("requests")
    .onSnapshot((snap) => {
      try {
        snap.docChanges().forEach((ch) => {
          if (ch.type !== "modified") return;
          const d = ch.doc.data();
          const st = d && d.status;
          if (st === "new" || st === "fresh") return; // pickup handled by (1)
          const key = `req:${ch.doc.id}:${String(st || "")}`;
          if (watcherSeen.has(key)) return;
          markSeen(key);
          Promise.resolve(pushStatusUpdate(d, String(st))).catch(() => {});
        });
      } catch (e) {
        console.error("[PUSH] status watcher error:", e.message);
      }
    });

  // (3) New chat message -> the recipient's device (skips the sender side).
  fcmDb
    .collectionGroup("messages")
    .onSnapshot((snap) => {
      try {
        snap.docChanges().forEach((ch) => {
          if (ch.type !== "added") return;
          const d = ch.doc.data();
          const msgKey = `msg:${ch.doc.id}`;
          if (watcherSeen.has(msgKey)) return;
          markSeen(msgKey);
          Promise.resolve(pushChatMessage(d, ch.doc.id)).catch(() => {});
        });
      } catch (e) {
        console.error("[PUSH] messages watcher error:", e.message);
      }
    });

  console.log("[PUSH] Firestore watchers started (requests + chat).");
  return true;
}

// Try to arm the watchers at boot; they stay silent without credentials.
startPushWatchers().then((on) => {
  if (!on) {
    console.log(
      "[PUSH] Disabled: no GOOGLE_APPLICATION_CREDENTIALS. " +
        "In-app notifications still work without the server."
    );
  }
});
