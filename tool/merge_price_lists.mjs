/**
 * Merges several parsed price-list JSON files into one, then reports how the
 * combined catalogue looks before anything is written to Firestore.
 *
 * Sections are keyed by their normalised name so the two sheets contribute to
 * the same section where they overlap, and a section present in either file
 * ends up with a single category document.
 *
 * Usage: node tool/merge_price_lists.mjs <out.json> <in.json> [in.json ...]
 */
import { readFileSync, writeFileSync } from 'node:fs';

const [outPath, ...inputs] = process.argv.slice(2);
if (!outPath || inputs.length === 0) {
  console.error('usage: node tool/merge_price_lists.mjs <out.json> <in.json>...');
  process.exit(1);
}

/** Normalises a section title so trivial spacing differences collapse. */
function key(sec) {
  return String(sec || '')
    .trim()
    .replace(/\s+/g, ' ');
}

const bySection = new Map();
let total = 0;
const allWarnings = [];

for (const file of inputs) {
  const { products, warnings } = JSON.parse(readFileSync(file, 'utf8'));
  console.log(`${file}: ${products.length} products`);
  allWarnings.push(...warnings.map((w) => `${file}: ${w}`));
  for (const p of products) {
    const k = key(p.section);
    if (!k) continue;
    if (!bySection.has(k)) bySection.set(k, []);
    bySection.get(k).push(p);
    total++;
  }
}

// A product whose document id would repeat would silently overwrite, so the
// merge is keyed on section + name and reports any duplicate it finds.
const seenIds = new Map();
const merged = [];
let dupes = 0;

for (const [sec, items] of bySection) {
  const seenNames = new Set();
  for (const p of items) {
    const name = String(p.name || '').trim();
    const dupKey = `${sec}::${name}`;
    if (seenNames.has(dupKey)) {
      dupes++;
      continue;
    }
    seenNames.add(dupKey);
    merged.push({ ...p, section: sec });
  }
}

console.log(`\nmerged: ${merged.length} products across ${bySection.size} sections`);
console.log(`duplicates dropped: ${dupes}`);
console.log(`warnings: ${allWarnings.length}`);

console.log('\nsections:');
for (const [sec, items] of [...bySection.entries()].sort((a, b) => b[1].length - a[1].length)) {
  console.log(`  ${items.length.toString().padStart(3)}  ${sec}`);
}

writeFileSync(
  outPath,
  JSON.stringify({ products: merged, warnings: allWarnings }, null, 2),
);
console.log(`\nwritten: ${outPath}`);