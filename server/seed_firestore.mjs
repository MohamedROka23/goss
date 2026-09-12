// Seeds Firestore with demo products from server/db.json using Firebase Admin SDK.
// Bypasses security rules (service-account access).
//
// Run:
//   npm install firebase-admin
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\gosst-service-account.json"
//   node server/seed_firestore.mjs
import { initializeApp, applicationDefault } from 'firebase-admin';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const dbJson = JSON.parse(readFileSync(path.join(dir, 'db.json'), 'utf8'));

initializeApp({
  projectId: 'gosst-9c2c6',
  credential: applicationDefault(),
});

const db = getFirestore();
const ts = FieldValue.serverTimestamp();

async function main() {
  await db.collection('admins').doc('Lt3KI3MAoIgnK1tt028suzJJDlq1').set({
    name: 'Gosst Master Admin',
    email: 'info@gossts.com',
    role: 'super',
    createdAt: ts,
  });
  console.log('Seeded admins/Lt3KI3MAoIgnK1tt028suzJJDlq1');

  for (const p of dbJson.products) {
    const costPrice = p.costPrice ?? Math.round(p.price * 0.75 * 100) / 100;
    await db.collection('products').doc(p.id).set({
      category: p.category,
      unit: p.unit,
      price: p.price,
      costPrice,
      nameEn: p.nameEn,
      nameAr: p.nameAr,
      descEn: p.descEn,
      descAr: p.descAr,
      createdAt: ts,
    });
    console.log(`Seeded products/${p.id} (${p.nameEn})`);
  }

  const defaultCategories = [
    { id: 'vegetables', en: 'Fresh Vegetables', ar: 'الخضروات الطازجة', order: 1 },
    { id: 'fruits', en: 'Fresh Fruits', ar: 'الفاكهة الطازجة', order: 2 },
    { id: 'general', en: 'General Goods', ar: 'عام', order: 3 },
    { id: 'office', en: 'Office Supplies', ar: 'الأدوات المكتبية', order: 4 },
    { id: 'hotel', en: 'Hotel Supplies', ar: 'أدوات فندقية', order: 5 },
    { id: 'restaurant', en: 'Restaurant Supplies', ar: 'لوازم المطاعم', order: 6 },
    { id: 'appliances', en: 'Appliances', ar: 'أجهزة', order: 7 },
    { id: 'packaging', en: 'Packaging & Wrapping Materials', ar: 'مواد التعبئة والتغليف', order: 8 },
  ];
  for (const c of defaultCategories) {
    await db.collection('categories').doc(c.id).set({
      en: c.en,
      ar: c.ar,
      order: c.order,
    });
    console.log(`Seeded categories/${c.id}`);
  }

  console.log('Done. All products are now visible to customers.');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});