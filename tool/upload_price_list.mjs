/**
 * Uploads the parsed price list into Firestore.
 *
 * Run indirectly via tool/parse_price_list.dart, which produces the JSON this
 * consumes. Uses firebase-admin, which the project's server already depends on,
 * so no new dependency is introduced.
 *
 * Product ids are built from the section and name with unsafe characters
 * removed rather than transliterated. The app's own importer derives ids from
 * the *English* name, which collapses to an empty string for Arabic-only input;
 * these ids are therefore built differently and are stable across re-runs.
 *
 * Usage:
 *   node tool/upload_price_list.mjs <jsonPath> [--dry-run] [--project <id>]
 */
import { readFileSync } from 'node:fs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const jsonPath = args[0];
const dryRun = args.includes('--dry-run');
const projectArgIndex = args.indexOf('--project');
const projectId =
  projectArgIndex >= 0 ? args[projectArgIndex + 1] : 'gosst-9c2c6';

if (!jsonPath) {
  console.error('usage: node tool/upload_price_list.mjs <json> [--dry-run]');
  process.exit(1);
}

const { products: allRows, warnings } = JSON.parse(readFileSync(jsonPath, 'utf8'));

// Category rows travel in the same file so the uploader can use the exact ids
// the parser chose. They are not products and must not be counted or written
// into /products.
const products = allRows.filter((r) => r.isCategory !== true);
const categoryRows = allRows.filter((r) => r.isCategory === true);

console.log(`parsed: ${products.length} products (+${categoryRows.length} categories)`);
console.log(`warnings from parser: ${warnings.length}`);
if (warnings.length) {
  const unique = [...new Set(warnings)];
  for (const w of unique.slice(0, 10)) console.log(`  ${w}`);
  if (unique.length > 10) console.log(`  ...and ${unique.length - 10} more`);
}

/**
 * A stable, URL-safe document id. Keeps Arabic characters (Firestore accepts
 * them) and strips only what a document path cannot contain. Falls back to a
 * row-derived id so no product can ever collide on an empty key.
 */
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

// Group products by section id. The app's parser already resolves each product
// to a category id, so that id is the grouping key and is never re-derived —
// deriving it again from the display name is what previously forked a second
// category beside an existing one.
const sections = new Map();
for (const p of products) {
  const sec = String(p.section || '').trim();
  if (!sec) continue;
  if (!sections.has(sec)) sections.set(sec, []);
  sections.get(sec).push(p);
}

// Display names for the categories, where the parser supplied them.
const catNameById = new Map();
for (const c of categoryRows) {
  const id = String(c.sectionId || '').trim();
  if (id) catNameById.set(id, String(c.name || '').trim());
}

console.log(`\nsections: ${sections.size}`);

// ── Enforce the "no product without a section" rule ─────────────────────
// The deployed Firestore rules now reject any product whose category does not
// exist, so an unlabelled row would fail at commit time. Rather than let a
// whole batch fail, unlabelled rows are reported and skipped up front.
const orphans = products.filter(
  (p) => !String(p.section || '').trim() || !sections.has(String(p.section).trim()),
);
if (orphans.length) {
  console.log(`\n!! ${orphans.length} product(s) have no usable section and will be SKIPPED:`);
  for (const o of orphans.slice(0, 20)) {
    console.log(`   row ${o.row}: "${o.name}"`);
  }
}
const valid = products.filter(
  (p) => String(p.section || '').trim() && sections.has(String(p.section).trim()),
);
console.log(`\nproducts to write: ${valid.length}/${products.length}`);

if (dryRun) {
  console.log('\n--dry-run: nothing written.');
  console.log('\nsample ids:');
  valid.slice(0, 5).forEach((p, i) => {
    console.log(
      `  ${docId('p', `${p.section} ${p.name}`, i + 1)}  |  ${p.name} | ${p.unit} | ${p.price}`,
    );
  });
  process.exit(0);
}

// ── Initialise the admin SDK with the project's service account ──────────
if (getApps().length === 0) {
  const sa = JSON.parse(
    readFileSync('gosst-9c2c6-firebase-adminsdk-fbsvc-1b7ca8434c.json', 'utf8'),
  );
  initializeApp({ credential: cert(sa), projectId });
}
const db = getFirestore();

const CHUNK = 450;
let productsWritten = 0;
let productsFailed = 0;
const failedNames = [];

// ── Categories ────────────────────────────────────────────────────────────
// The grouping key IS the category id, because the app's parser resolved every
// product to an existing category where one matched. Writing the key straight
// through is what guarantees a product and its section share the same id.
const catIds = new Map();
let order = Date.now();
const catEntries = [];
for (const sec of sections.keys()) {
  catIds.set(sec, sec);
  catEntries.push({ id: sec, sec });
}

for (let i = 0; i < catEntries.length; i += CHUNK) {
  const batch = db.batch();
  for (const { id, sec } of catEntries.slice(i, i + CHUNK)) {
    const display = catNameById.get(id) || sec;
    batch.set(db.collection('categories').doc(id), {
      id,
      en: display,
      ar: display,
      order: order++,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`  categories ${Math.min(i + CHUNK, catEntries.length)}/${catEntries.length}`);
}

// ── Products + costs ──────────────────────────────────────────────────────
// Both writes ride in the same batch so a product never exists without its cost
// record; the app reads prices from /products and costs from /product_costs.
for (let i = 0; i < valid.length; i += CHUNK) {
  const slice = valid.slice(i, i + CHUNK);
  const batch = db.batch();
  for (const [offset, p] of slice.entries()) {
    const index = i + offset + 1;
    const sec = String(p.section || '').trim();

    // The category field MUST be the category *document id*, not the section
    // name. The app filters with `p.category == c.id`, so writing the name here
    // leaves the product visible under "All" but absent from its own section —
    // which is exactly the bug this replaced.
    const categoryId = catIds.get(sec);
    if (!categoryId) {
      productsFailed++;
      failedNames.push(`${p.name} (no category for section "${sec}")`);
      continue;
    }

    const id = docId('p', `${categoryId} ${p.name}`, index);

    batch.set(db.collection('products').doc(id), {
      id,
      category: categoryId,
      unit: p.unit || 'unit',
      price: Number(p.price) || 0,
      stock: 0,
      nameEn: p.name,
      nameAr: p.name,
      descEn: '',
      descAr: '',
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('product_costs').doc(id), {
      costPrice: 0,
    });
  }
  try {
    await batch.commit();
    productsWritten += slice.length;
  console.log(`  products ${productsWritten}/${valid.length}`);
  } catch (e) {
    // Fall back to per-document writes so one bad record cannot lose a whole
    // chunk of 450.
    productsFailed += slice.length;
    for (const [offset, p] of slice.entries()) {
      const index = i + offset + 1;
      const sec = String(p.section || '').trim();
      const categoryId = catIds.get(sec);
      if (!categoryId) {
        productsFailed++;
        failedNames.push(`${p.name} (no category for section "${sec}")`);
        continue;
      }
      const id = docId('p', `${categoryId} ${p.name}`, index);
      try {
        await db.collection('products').doc(id).set({
          id,
          category: categoryId,
          unit: p.unit || 'unit',
          price: Number(p.price) || 0,
          stock: 0,
          nameEn: p.name,
          nameAr: p.name,
          descEn: '',
          descAr: '',
          createdAt: FieldValue.serverTimestamp(),
        });
        await db.collection('product_costs').doc(id).set({ costPrice: 0 });
        productsFailed--;
        productsWritten++;
      } catch (e2) {
        failedNames.push(`${p.name} (${e2.code || e2.message})`);
      }
    }
  }
}

console.log('');
console.log(`categories: ${catEntries.length}`);
console.log(`products written: ${productsWritten}`);
console.log(`products failed: ${productsFailed}`);
if (failedNames.length) {
  console.log('failures:');
  for (const f of failedNames.slice(0, 20)) console.log(`  ${f}`);
}
