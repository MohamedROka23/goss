/**
 * Repairs `products.category` so every product points at a real category
 * document id.
 *
 * The first upload wrote the section *name* into `products.category`, but the
 * app filters with `p.category == c.id` against the categories collection. A
 * product therefore appeared under "All" but never under its own section.
 *
 * This script:
 *   1. reads the real category ids currently in Firestore,
 *   2. matches each product by its stored `category` value (either the name or
 *      an id), and
 *   3. rewrites the field to the matching id.
 *
 * Usage: node tool/fix_product_categories.mjs [--dry-run]
 */
import { readFileSync } from 'node:fs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const dryRun = process.argv.includes('--dry-run');
const projectId = 'gosst-9c2c6';

if (getApps().length === 0) {
  const sa = JSON.parse(
    readFileSync('gosst-9c2c6-firebase-adminsdk-fbsvc-1b7ca8434c.json', 'utf8'),
  );
  initializeApp({ credential: cert(sa), projectId });
}
const db = getFirestore();

/** The same id scheme the uploader used, kept in sync with upload_price_list.mjs. */
function docId(prefix, text, index) {
  const base = String(text)
    .trim()
    .toLowerCase()
    .replace(/[\\/:*?"<>|\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 120);
  return `${prefix}-${base || `item-${index}`}`;
}

// Read every category and index it by id, en, ar and the id-without-prefix so a
// product written with any of those forms resolves.
const catSnapshot = await db.collection('categories').get();
console.log(`categories in Firestore: ${catSnapshot.size}`);

const byId = new Map();
for (const doc of catSnapshot.docs) {
  const d = doc.data();
  byId.set(doc.id, doc.id);
  if (d.en) byId.set(String(d.en).trim(), doc.id);
  if (d.ar) byId.set(String(d.ar).trim(), doc.id);
  if (doc.id.startsWith('cat-')) byId.set(doc.id.slice(4), doc.id);
}

const productsSnapshot = await db.collection('products').get();
console.log(`products in Firestore: ${productsSnapshot.size}\n`);

const updates = [];
const unresolved = new Map();

for (const doc of productsSnapshot.docs) {
  const current = doc.data().category;
  if (current == null || current === '') continue;

  // Already pointing at a real id? Nothing to do.
  if (catSnapshot.docs.some((c) => c.id === current)) continue;

  const target = byId.get(String(current).trim());
  if (target) {
    updates.push({ doc, from: current, to: target });
  } else {
    unresolved.set(String(current), (unresolved.get(String(current)) || 0) + 1);
  }
}

console.log(`need fixing: ${updates.length}`);
for (const u of updates.slice(0, 5)) {
  console.log(`  "${u.from}"  ->  "${u.to}"`);
}

if (unresolved.size) {
  console.log(`\nunresolved category values (${unresolved.size}):`);
  for (const [k, v] of unresolved) console.log(`  "${k}" x${v}`);
}

if (dryRun) {
  console.log('\n--dry-run: nothing written.');
  process.exit(0);
}

const BATCH = 400;
for (let i = 0; i < updates.length; i += BATCH) {
  const batch = db.batch();
  for (const u of updates.slice(i, i + BATCH)) {
    batch.update(u.doc.ref, { category: u.to });
  }
  await batch.commit();
  console.log(`  fixed ${Math.min(i + BATCH, updates.length)}/${updates.length}`);
}

console.log(`\ndone: ${updates.length} products re-pointed at their category id`);