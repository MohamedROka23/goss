// One-time migration: moves supplier cost prices out of the world-readable
// /products collection into /product_costs, which firestore.rules restricts to
// the quotes panel.
//
// WHY: /products has `allow read: if true` (the customer catalogue) and Firestore
// rules cannot redact individual fields from a granted read, so any cost stored
// on a product document is public to anyone with the project's Web API key.
// The app now writes costs to /product_costs; this script moves the data that
// already exists in production.
//
// SAFE BY DEFAULT: prints a plan and exits unless --apply is passed.
//
// Run:
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\gosst-service-account.json"
//   node server/migrate_product_costs.mjs            # dry run
//   node server/migrate_product_costs.mjs --apply    # performs the move
import { initializeApp, applicationDefault } from 'firebase-admin';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const APPLY = process.argv.includes('--apply');
const BATCH_LIMIT = 400;

initializeApp({
  projectId: 'gosst-9c2c6',
  credential: applicationDefault(),
});

const db = getFirestore();

async function main() {
  const products = await db.collection('products').get();
  const movable = products.docs.filter((d) => d.data().costPrice !== undefined);

  console.log(`Scanned ${products.docs.length} product document(s).`);
  console.log(`${movable.length} still carry an inline costPrice.`);
  if (movable.length === 0) {
    console.log('Nothing to do.');
    process.exit(0);
  }
  for (const d of movable) {
    console.log(`  products/${d.id} costPrice=${d.data().costPrice}`);
  }

  if (!APPLY) {
    console.log('\nDry run only. Re-run with --apply to move these costs.');
    process.exit(0);
  }

  let moved = 0;
  for (let i = 0; i < movable.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const d of movable.slice(i, i + BATCH_LIMIT)) {
      const { costPrice, ...rest } = d.data();
      batch.set(
        db.collection('product_costs').doc(d.id),
        { costPrice, movedAt: FieldValue.serverTimestamp() },
      );
      // Overwrite the product document without the cost field. Firestore rules
      // never applied here (Admin SDK), and the field must be gone, not nulled.
      batch.set(db.collection('products').doc(d.id), rest);
    }
    await batch.commit();
    moved += movable.slice(i, i + BATCH_LIMIT).length;
    console.log(`Migrated ${moved}/${movable.length}...`);
  }

  console.log(`\nDone. ${moved} cost price(s) moved to /product_costs.`);
  console.log('Deploy the updated rules now: firebase deploy --only firestore:rules');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
