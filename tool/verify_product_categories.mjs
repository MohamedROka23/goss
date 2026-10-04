/**
 * Verifies the catalogue's core invariant: every product points at a category
 * document that exists.
 *
 * This is the check behind "a product must never be uploaded without a
 * section". It reads Firestore directly, so it catches anything written by the
 * uploader scripts, by the in-app importer, or by hand.
 *
 * Usage: node tool/verify_product_categories.mjs
 */
import { readFileSync } from 'node:fs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = 'gosst-9c2c6';

if (getApps().length === 0) {
  const sa = JSON.parse(
    readFileSync('gosst-9c2c6-firebase-adminsdk-fbsvc-1b7ca8434c.json', 'utf8'),
  );
  initializeApp({ credential: cert(sa), projectId });
}
const db = getFirestore();

const catSnapshot = await db.collection('categories').get();
const catIds = new Set(catSnapshot.docs.map((d) => d.id));
console.log(`categories: ${catIds.size}`);

const products = await db.collection('products').get();
console.log(`products:   ${products.size}\n`);

const orphanDocs = [];
const byCategory = new Map();

for (const doc of products.docs) {
  const cat = doc.data().category;
  if (typeof cat !== 'string' || cat.trim() === '') {
    orphanDocs.push({ name: doc.data().nameEn || doc.id, reason: 'empty category' });
    continue;
  }
  if (!catIds.has(cat)) {
    orphanDocs.push({ name: doc.data().nameEn || doc.id, reason: `"${cat}" does not exist` });
    continue;
  }
  byCategory.set(cat, (byCategory.get(cat) || 0) + 1);
}

// Cost records must exist for every product, since the app reads the supplier
// cost from a sibling document.
const costs = await db.collection('product_costs').get();
const costIds = new Set(costs.docs.map((d) => d.id));
const missingCost = products.docs.filter((d) => !costIds.has(d.id)).map((d) => d.data().nameEn || d.id);

console.log(`product_costs: ${costs.size}`);
console.log(`\nproducts grouped by section (${byCategory.size} sections in use):`);
for (const [cat, count] of [...byCategory.entries()].sort((a, b) => b[1] - a[1])) {
  const meta = catSnapshot.docs.find((d) => d.id === cat)?.data() || {};
  console.log(`  ${String(count).padStart(3)}  ${meta.ar || meta.en || cat}`);
}

const unusedCats = [...catIds].filter((id) => !byCategory.has(id));

console.log(`\nempty sections (no products): ${unusedCats.length}`);
for (const c of unusedCats) {
  const meta = catSnapshot.docs.find((d) => d.id === c)?.data() || {};
  console.log(`  ${meta.ar || meta.en || c}`);
}

console.log(`\nproducts with a missing/invalid section: ${orphanDocs.length}`);
for (const o of orphanDocs.slice(0, 25)) console.log(`  ${o.name} — ${o.reason}`);

console.log(`products with no cost record: ${missingCost.length}`);
for (const m of missingCost.slice(0, 15)) console.log(`  ${m}`);

const ok = orphanDocs.length === 0 && missingCost.length === 0;
console.log(`\n${ok ? 'PASS' : 'FAIL'}: every product belongs to a real section`);
process.exit(ok ? 0 : 1);