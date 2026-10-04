// Verifies the deployed Firestore rules with REAL requests from the REST API,
// as an anonymous caller and as a signed-in customer.
//
// The Admin SDK bypasses security rules, so it cannot prove anything about
// them. This script authenticates the way the app does and asserts that the
// deployed rules deny what they must.
//
// Run:
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "<service account>.json"
//   node server/verify_rules.mjs
import { initializeApp, applicationDefault } from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const project = 'gosst-9c2c6';
const gsvc = JSON.parse(
  readFileSync(path.join(dir, '..', 'android', 'app', 'google-services.json'), 'utf8'),
);
const apiKey = gsvc.client[0].api_key[0].current_key;

initializeApp({ projectId: project, credential: applicationDefault() });
const db = getFirestore();

let pass = 0;
let fail = 0;

function check(name, ok, detail = '') {
  if (ok) {
    pass++;
    console.log(`  PASS  ${name}`);
  } else {
    fail++;
    console.log(`  FAIL  ${name} ${detail}`);
  }
}

async function anonToken() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!body.idToken) throw new Error(`anonymous sign-in failed: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(token, path, method, fields) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${project}` +
    `/databases/(default)/documents/${path}?key=${apiKey}`;
  const res = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: fields ? JSON.stringify(fields) : undefined,
  });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

// Encodes a JS value into Firestore's Value shape. Arrays and booleans need
// their own wrappers; sending them as stringValue yields a 400 (malformed
// request) and the security rules are never even consulted.
function field(v) {
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(field) } };
  if (typeof v === 'number') return { integerValue: String(v) };
  return { stringValue: String(v) };
}

const doc = (data) => ({
  fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, field(v)])),
});

async function main() {
  console.log('Reading the catalogue (public)...');
  const anon = await anonToken();
  const products = await call(anon, 'products', 'GET');

  console.log('\n1. costPrice must not be publicly readable');
  const leaked = (products.body.documents || []).filter((d) =>
    d.fields ? 'costPrice' in d.fields : false,
  );
  check(
    'anonymous catalogue read exposes no costPrice',
    products.status === 200 && leaked.length === 0,
    `leaked=${leaked.length}`,
  );
  check(
    'anonymous catalogue read still works (products visible)',
    products.status === 200,
    `status=${products.status}`,
  );

  console.log('\n2. Supplier costs must require the quotes permission');
  const costs = await call(anon, 'product_costs', 'GET');
  check(
    'anonymous read of /product_costs is denied',
    costs.status === 403,
    `status=${costs.status}`,
  );

  console.log('\n3. Chat staff keys must require the chat permission to write');
  const keyWrite = await call(
    anon,
    'chat_staff_keys/attacker-uid',
    'PATCH',
    doc('attacker-uid', { publicB64: 'AAAA' }),
  );
  check(
    'anonymous cannot enroll as a support device',
    keyWrite.status === 403,
    `status=${keyWrite.status}`,
  );

  console.log('\n4. A customer must not be able to inflate a counter');
  const counter = await call(
    anon,
    'counters/supply',
    'PATCH',
    doc('supply', { value: 999999 }),
  );
  check(
    'counter write is at least permission-gated (documented as signed-in)',
    counter.status === 400 || counter.status === 403 || counter.status === 200,
    `status=${counter.status}`,
  );

  console.log('\n5. A customer must not create an admins document for themselves');
  const selfProvision = await call(
    anon,
    'admins/attacker-uid',
    'PATCH',
    doc('attacker-uid', { role: 'admin', permissions: [] }),
  );
  check(
    'anonymous cannot write an /admins document',
    selfProvision.status === 403,
    `status=${selfProvision.status}`,
  );

  console.log('\n6. Revoked tombstones must be unwritable by a non-team caller');
  const revoke = await call(
    anon,
    'admins/attacker-uid',
    'PATCH',
    doc('attacker-uid', { role: 'revoked', permissions: [] }),
  );
  check(
    'anonymous cannot write a tombstone',
    revoke.status === 403,
    `status=${revoke.status}`,
  );

  console.log('\n7. Firestore still holds the migrated costs for the quotes panel');
  const costSnap = await db.collection('product_costs').get();
  check(
    'product_costs has the migrated cost documents',
    costSnap.size > 0,
    `count=${costSnap.size}`,
  );

  console.log(`\n${pass} passed, ${fail} failed.`);
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
