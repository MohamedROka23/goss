import express from "express";
import cors from "cors";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { initializeApp, applicationDefault } from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { randomBytes, scryptSync, timingSafeEqual } from "crypto";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, "db.json");
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "GOSST@admin";
const TOKEN = "goss-admin-session";

// Unique resource ids keep their stable prefix (u-, p-, r-, pu-, ex-, n-)
// with a random suffix so concurrent creates can never collide.
function newId(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

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
const PERMISSION_KEYS = ["requests", "customers", "quotes", "purchases", "profit", "expenses", "tracking", "team"];
const DEFAULT_PERMISSIONS = {
  super: [...PERMISSION_KEYS],
  admin: [...PERMISSION_KEYS],
  delegate: ["requests", "customers", "tracking"],
};
const TEAM_ROLES = ["super", "admin", "delegate"];

const STATUS_LABELS = {
  fresh: { en: "New request", ar: "طلب جديد" },
  accepted: { en: "Order received — we got your request", ar: "تم استلام الطلب" },
  preparing: { en: "Your order is being prepared", ar: "جاري التجهيز" },
  arriving: { en: "On the way to your location", ar: "جاري الوصول للموقع" },
  delivering: { en: "Out for delivery", ar: "جاري التسليم" },
  delivered: { en: "Delivered", ar: "تم التسليم" },
  confirmed: { en: "Delivery confirmed", ar: "مؤكد التسليم" },
  rejected: { en: "Delivery rejected by customer", ar: "تم رفض التسليم" },
};

const seed = {
  products: [
    {
      id: "veg-tomato",
      category: "vegetables",
      unit: "kg",
      price: 18.5,
      nameEn: "Fresh Tomatoes",
      nameAr: "طماطم طازجة",
      descEn: "Farm-fresh tomatoes under unbroken cold-chain.",
      descAr: "طماطم طازجة من المزرعة ضمن سلسلة تبريد متصلة.",
    },
    {
      id: "veg-potato",
      category: "vegetables",
      unit: "kg",
      price: 12,
      nameEn: "Potatoes",
      nameAr: "بطاطس",
      descEn: "Sorted potatoes for hospitality and corporate kitchens.",
      descAr: "بطاطس مفروزة لمطابخ الفنادق والشركات.",
    },
    {
      id: "veg-onion",
      category: "vegetables",
      unit: "kg",
      price: 14,
      nameEn: "Onions",
      nameAr: "بصل",
      descEn: "Bulk onions with international sorting standards.",
      descAr: "بصل بكميات كبيرة وفق معايير فرز دولية.",
    },
    {
      id: "veg-cucumber",
      category: "vegetables",
      unit: "kg",
      price: 16,
      nameEn: "Cucumbers",
      nameAr: "خيار",
      descEn: "Premium cucumbers for HORECA supply.",
      descAr: "خيار فاخر لتوريد قطاع الضيافة.",
    },
    {
      id: "veg-lettuce",
      category: "vegetables",
      unit: "kg",
      price: 22,
      nameEn: "Lettuce",
      nameAr: "خس",
      descEn: "Crisp lettuce packed for corporate catering.",
      descAr: "خس مقرمش معبأ للكيترينج المؤسسي.",
    },
    {
      id: "fru-orange",
      category: "fruits",
      unit: "kg",
      price: 20,
      nameEn: "Oranges",
      nameAr: "برتقال",
      descEn: "Seasonal oranges packed to export grade.",
      descAr: "برتقال موسمي بتعبئة درجة تصدير.",
    },
    {
      id: "fru-apple",
      category: "fruits",
      unit: "kg",
      price: 35,
      nameEn: "Apples",
      nameAr: "تفاح",
      descEn: "Hand-selected apples for hospitality service.",
      descAr: "تفاح منتقى يدوياً لقطاع الضيافة.",
    },
    {
      id: "fru-banana",
      category: "fruits",
      unit: "kg",
      price: 24,
      nameEn: "Bananas",
      nameAr: "موز",
      descEn: "Rapid-transit bananas for maximum freshness.",
      descAr: "موز بنقل سريع للحفاظ على الطزاجة.",
    },
    {
      id: "fru-strawberry",
      category: "fruits",
      unit: "kg",
      price: 55,
      nameEn: "Strawberries",
      nameAr: "فراولة",
      descEn: "Premium seasonal strawberries.",
      descAr: "فراولة موسمية فاخرة.",
    },
    {
      id: "hot-linen",
      category: "hotel",
      unit: "set",
      price: 480,
      nameEn: "Luxury Linen Set",
      nameAr: "طقم مفروشات فاخر",
      descEn: "Hotel-grade linens and textiles.",
      descAr: "مفروشات ومنسوجات بدرجة فندقية.",
    },
    {
      id: "hot-towel",
      category: "hotel",
      unit: "dozen",
      price: 260,
      nameEn: "Commercial Towels",
      nameAr: "مناشف تجارية",
      descEn: "Absorbency-tested towels for guest rooms.",
      descAr: "مناشف مختبرة للغرف الفندقية.",
    },
    {
      id: "hot-amenity",
      category: "hotel",
      unit: "kit",
      price: 95,
      nameEn: "Guest Amenities Kit",
      nameAr: "طقم مستلزمات النزيل",
      descEn: "Premium guest amenities for hospitality.",
      descAr: "مستلزمات نزلاء فاخرة للضيافة.",
    },
    {
      id: "off-paper",
      category: "office",
      unit: "ream",
      price: 85,
      nameEn: "A4 Copy Paper",
      nameAr: "ورق تصوير A4",
      descEn: "Bulk paper for daily office operations.",
      descAr: "ورق بكميات للمكاتب اليومية.",
    },
    {
      id: "off-pen",
      category: "office",
      unit: "box",
      price: 45,
      nameEn: "Corporate Pens",
      nameAr: "أقلام مكتبية",
      descEn: "Office stationery for administrative teams.",
      descAr: "قرطاسية مكتبية للفرق الإدارية.",
    },
    {
      id: "off-folder",
      category: "office",
      unit: "pack",
      price: 70,
      nameEn: "Filing Folders",
      nameAr: "ملفات تنظيم",
      descEn: "Corporate filing and printing supplies.",
      descAr: "ملفات ومستلزمات طباعة للشركات.",
    },
    {
      id: "pkg-carton",
      category: "packaging",
      unit: "piece",
      price: 18,
      nameEn: "Heavy-duty Shipping Carton",
      nameAr: "كرتون شحن قوي",
      descEn: "Cartons tailored for corporate transport.",
      descAr: "كراتين مخصصة للنقل المؤسسي.",
    },
    {
      id: "pkg-bubble",
      category: "packaging",
      unit: "roll",
      price: 120,
      nameEn: "Bubble Wrap Roll",
      nameAr: "رول فقاعات حماية",
      descEn: "Protective wrap and seals for cargo.",
      descAr: "تغليف حماية وأختام للشحنات.",
    },
    {
      id: "pkg-stretch",
      category: "packaging",
      unit: "roll",
      price: 150,
      nameEn: "Stretch Film",
      nameAr: "فيلم تغليف مطاطي",
      descEn: "Secure wrapping for warehouse staging.",
      descAr: "تغليف آمن لتجهيز المستودعات.",
    },
  ],
  requests: [],
  purchases: [],
  expenses: [],
  notifications: [],
  categories: [
    { id: "vegetables", en: "Fresh Vegetables", ar: "الخضروات الطازجة", order: 1 },
    { id: "fruits", en: "Fresh Fruits", ar: "الفاكهة الطازجة", order: 2 },
    { id: "general", en: "General Goods", ar: "عام", order: 3 },
    { id: "office", en: "Office Supplies", ar: "الأدوات المكتبية", order: 4 },
    { id: "hotel", en: "Hotel Supplies", ar: "أدوات فندقية", order: 5 },
    { id: "restaurant", en: "Restaurant Supplies", ar: "لوازم المطاعم", order: 6 },
    { id: "appliances", en: "Appliances", ar: "أجهزة", order: 7 },
    { id: "packaging", en: "Packaging & Wrapping Materials", ar: "مواد التعبئة والتغليف", order: 8 },
  ],
  users: [
    {
      id: "u-admin",
      name: "Gosst Admin",
      email: "info@gosst.com",
      password: "123456",
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
  const header = req.headers.authorization || "";
  if (header !== `Bearer ${TOKEN}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
}

// --- Firebase Cloud Messaging (push) ---------------------------------------
// Enabled at runtime when a service-account credential is available
// (GOOGLE_APPLICATION_CREDENTIALS). Without it, notify endpoints respond 503
// and the app silently falls back to in-app stream updates.

let fcmDb = null;
let fcmMessaging = null;
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
app.use(cors({ origin: (origin, cb) => cb(null, allowedOrigin(origin)) }));
app.use(express.json({ limit: "1mb" }));

// minimal request logging to observe app traffic during local testing
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  next();
});

app.get("/api/products", (_req, res) => {
  res.json(loadDb().products);
});

app.get("/api/categories", (_req, res) => {
  const db = loadDb();
  if (!db.categories) db.categories = [];
  res.json(db.categories);
});

app.post("/api/categories", auth, (req, res) => {
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

app.post("/api/login", (req, res) => {
  const { email, password } = req.body || {};
  // Legacy: single master password only.
  if (!email && password === ADMIN_PASSWORD) {
    return res.json({ token: TOKEN });
  }
  const users = (loadDb().users || []);
  const user = users.find(
    (u) => u.email === (email || "").toLowerCase() && verifyPassword(password, u.password)
  );
  if (!user) {
    return res.status(401).json({ error: "Invalid email or password" });
  }
  res.json({ token: TOKEN });
});

app.post("/api/register", (req, res) => {
  const { name, email, password, code } = req.body || {};
  if (code !== ADMIN_PASSWORD) {
    return res.status(401).json({ error: "Invalid registration code" });
  }
  if (!name || !email || !password) {
    return res.status(400).json({ error: "Missing details" });
  }
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
    role: "admin",
    permissions: [...DEFAULT_PERMISSIONS.admin],
  };
  db.users.push(user);
  saveDb(db);
  res.status(201).json({ id: user.id });
});

app.post("/api/change-password", (req, res) => {
  const { email, oldPassword, newPassword } = req.body || {};
  const db = loadDb();
  const user = (db.users || []).find(
    (u) => u.email === (email || "").toLowerCase() && verifyPassword(oldPassword, u.password)
  );
  if (!user) return res.status(401).json({ error: "Invalid credentials" });
  user.password = hashPassword(newPassword);
  saveDb(db);
  res.json({ ok: true });
});

function publicUser(u) {
  return { id: u.id, name: u.name, email: u.email, role: u.role, permissions: u.permissions || [] };
}

app.get("/api/admins", auth, (_req, res) => {
  res.json((loadDb().users || []).filter((u) => TEAM_ROLES.includes(u.role)).map(publicUser));
});

app.post("/api/admins", auth, (req, res) => {
  const { name, email, password, role, permissions } = req.body || {};
  if (!name || !email || !password) {
    return res.status(400).json({ error: "Missing details" });
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

app.patch("/api/admins/:id", auth, (req, res) => {
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

app.delete("/api/admins/:id", auth, (req, res) => {
  const db = loadDb();
  const i = (db.users || []).findIndex((u) => u.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  const target = db.users[i];
  if (target.id === "u-admin") return res.status(403).json({ error: "Cannot remove the owner" });
  if (target.role === "super") return res.status(403).json({ error: "Cannot remove a super admin" });
  db.users.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

app.post("/api/products", auth, (req, res) => {
  const db = loadDb();
  const product = {
    id: newId("p"),
    category: req.body.category || "office",
    unit: req.body.unit || "unit",
    price: Number(req.body.price) || 0,
    costPrice: Number(req.body.costPrice) || Math.round(Number(req.body.price) * 0.75 * 100) / 100,
    nameEn: req.body.nameEn || "",
    nameAr: req.body.nameAr || "",
    descEn: req.body.descEn || "",
    descAr: req.body.descAr || "",
  };
  db.products.push(product);
  saveDb(db);
  res.status(201).json(product);
});

const PRODUCT_FIELDS = ["category", "unit", "price", "costPrice", "nameEn", "nameAr", "descEn", "descAr"];

app.put("/api/products/:id", auth, (req, res) => {
  const db = loadDb();
  const i = db.products.findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  const updated = { ...db.products[i], id: db.products[i].id };
  for (const key of PRODUCT_FIELDS) {
    if (typeof req.body[key] !== "undefined") {
      updated[key] = (key === "price" || key === "costPrice") ? Number(req.body[key]) : req.body[key];
    }
  }
  db.products[i] = updated;
  saveDb(db);
  res.json(db.products[i]);
});

app.delete("/api/products/:id", auth, (req, res) => {
  const db = loadDb();
  const i = db.products.findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.products.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

app.get("/api/requests", auth, (_req, res) => {
  res.json(loadDb().requests);
});

app.post("/api/requests", (req, res) => {
  const { company, name, phone, email, notes, items, customerId } = req.body || {};
  if (!name || !phone || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "Missing request details" });
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
  };
  db.requests.unshift(request);
  saveDb(db);
  res.status(201).json(request);
});

// Public: a customer's own requests (identified by the persistent customer id)
app.get("/api/requests/mine", (req, res) => {
  const cid = String(req.query.customerId || "");
  if (!cid) return res.json([]);
  const all = (loadDb().requests || []).filter((r) => r.customerId === cid);
  res.json(all);
});

async function pushStatusUpdate(request, status) {
  if (!(await initFcm()) || !request || !request.customerId) return;
  try {
    const label = STATUS_LABELS[status] || STATUS_LABELS.fresh;
    const body = status === "accepted"
      ? `${request.name} · ${label.en} — delivery within 48 hours from acceptance.`
      : `${request.name} · ${label.en}`;
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

app.patch("/api/requests/:id", auth, async (req, res) => {
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
  // notify all admin devices that the goods were delivered
  if (await initFcm()) {
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
  if (await initFcm()) {
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
app.get("/api/purchases", auth, (_req, res) => {
  res.json((loadDb().purchases || []).reverse());
});

app.post("/api/purchases", auth, (req, res) => {
  const db = loadDb();
  const qty = Number(req.body.qty) || 0;
  const costPrice = Number(req.body.costPrice) || 0;
  const purchase = {
    id: newId("pu"),
    date: new Date().toISOString(),
    supplier: req.body.supplier || "",
    productId: req.body.productId || "",
    qty,
    costPrice,
    total: qty * costPrice,
  };
  if (!db.purchases) db.purchases = [];
  db.purchases.unshift(purchase);
  saveDb(db);
  res.status(201).json(purchase);
});

app.delete("/api/purchases/:id", auth, (req, res) => {
  const db = loadDb();
  const i = (db.purchases || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.purchases.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

const PURCHASE_FIELDS = ["supplier", "productId", "qty", "costPrice"];

app.patch("/api/purchases/:id", auth, (req, res) => {
  const db = loadDb();
  const i = (db.purchases || []).findIndex((p) => p.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  for (const key of PURCHASE_FIELDS) {
    if (typeof req.body[key] === "undefined") continue;
    if (key === "qty") db.purchases[i].qty = Math.max(0, Number(req.body[key]) || 0);
    else if (key === "costPrice") db.purchases[i].costPrice = Number(req.body[key]) || 0;
    else db.purchases[i][key] = req.body[key];
  }
  db.purchases[i].total = db.purchases[i].qty * db.purchases[i].costPrice;
  saveDb(db);
  res.json(db.purchases[i]);
});

// Expenses
app.get("/api/expenses", auth, (_req, res) => {
  res.json((loadDb().expenses || []).reverse());
});

app.post("/api/expenses", auth, (req, res) => {
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

app.delete("/api/expenses/:id", auth, (req, res) => {
  const db = loadDb();
  const i = (db.expenses || []).findIndex((e) => e.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: "Not found" });
  db.expenses.splice(i, 1);
  saveDb(db);
  res.json({ ok: true });
});

const EXPENSE_FIELDS = ["date", "category", "description", "amount"];

app.patch("/api/expenses/:id", auth, (req, res) => {
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

// External push: new customer request -> all admin devices
app.post("/api/notify/request", async (req, res) => {
  if (!(await initFcm())) return res.status(503).json({ error: "FCM not configured" });
  try {
    const { customerName, itemsCount } = req.body || {};
    const tokens = await fetchTokens("admin_tokens");
    const result = await sendPush(
      tokens,
      "GOSST \u2014 New request",
      `${customerName || "A customer"} sent a request (${itemsCount || 0} items)`,
      { type: "new_request" }
    );
    res.json({ ok: true, ...result });
  } catch (e) {
    console.error("notify/request failed:", e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// External push: admin updated a price -> all customer devices
app.post("/api/notify/price-update", async (req, res) => {
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
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.post("/api/notifications", auth, (req, res) => {
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

const dist = path.join(__dirname, "..", "dist");
if (fs.existsSync(dist)) {
  app.use(express.static(dist));
  app.get("*", (_req, res) => res.sendFile(path.join(dist, "index.html")));
}app.listen(4000, () => {
  console.log("GOSST API on http://127.0.0.1:4000");
});
