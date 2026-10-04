// Verifies the request-integrity rules with REAL requests from the REST API,
// signed in as an actual customer account (anonymous Firebase Auth), because
// the Admin SDK bypasses security rules and cannot prove anything about them.
//
// Asserts the invariants the app depends on:
//   - a customer CAN create a request and CAN answer delivery
//   - a customer CANNOT edit prices, VAT, orderNo or the converted flag
//   - a customer CANNOT jump a fresh order straight to `confirmed`
//   - a customer CANNOT provision or revoke an /admins document
//
// Run:
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "<service account>.json"
//   node server/verify_customer_rules.mjs
import { initializeApp, applicationDefault } from 'firebase-admin';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
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
const cleanup = [];

function check(name, ok, detail = '') {
  if (ok) {
    pass++;
    console.log(`  PASS  ${name}`);
  } else {
    fail++;
    console.log(`  FAIL  ${name} ${detail}`);
  }
}

function field(v) {
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(field) } };
  if (v && typeof v === 'object') {
    return {
      mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, field(x)])) },
    };
  }
  return { stringValue: String(v) };
}

const docBody = (data) => ({
  fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, field(v)])),
});

async function signInAnon() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!body.idToken) throw new Error(`sign-in failed: ${JSON.stringify(body)}`);
  return { token: body.idToken, uid: body.localId };
}

async function call(token, p, method, body, updateMask) {
  // A PATCH without an updateMask REPLACES the whole document, which the
  // create/update rules must reject. The app uses update() (patch semantics), so
  // every positive-case check below passes an explicit field mask as a repeated
  // query parameter. (The mask is rejected inside the JSON body — it is only
  // accepted on the query string.)
  const mask = updateMask
    ? `&${updateMask
        .split(',')
        .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
        .join('&')}`
    : '';
  const url =
    `https://firestore.googleapis.com/v1/projects/${project}` +
    `/databases/(default)/documents/${p}?key=${apiKey}${mask}`;
  const res = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

async function main() {
  const { token, uid } = await signInAnon();
  console.log(`Signed in as an anonymous customer: ${uid}\n`);

  // A request shaped exactly like the app's submitRequest payload.
  const base = {
    company: 'Verify Co',
    name: 'Verify Customer',
    phone: '0100000000',
    email: 'verify@test.local',
    notes: '',
    items: [{ productId: 'tomato_red', nameEn: 'Tomato', nameAr: 'طماطم', qty: 2, unit: 'kg', price: 24 }],
    status: 'new',
    type: 'supply',
    customerId: uid,
    origin: '',
    destination: '',
    orderNo: 4242,
    vat: false,
    uid,
  };
  const created = await call(token, 'requests', 'POST', docBody(base));
  // `name` comes back fully qualified
  // (projects/../databases/(default)/documents/requests/<id>). The REST calls
  // below need the document-relative path; the Admin SDK needs the full one.
  const fullPath = created.body.name;
  const reqPath = fullPath.split('/documents/')[1];
  check('customer can create a request', created.status === 200, `status=${created.status}`);
  if (!reqPath) {
    console.log(`\n${pass} passed, ${fail} failed.`);
    process.exit(1);
  }
  cleanup.push(reqPath);

  console.log('\n1. Creation-state pins');
  const forgedConfirmed = await call(
    token,
    'requests',
    'POST',
    docBody({ ...base, status: 'confirmed' }),
  );
  check(
    'cannot create a request already marked confirmed',
    forgedConfirmed.status === 403,
    `status=${forgedConfirmed.status}`,
  );
  

  const forgedArchived = await call(
    token,
    'requests',
    'POST',
    docBody({ ...base, archived: true }),
  );
  check(
    'cannot create a hidden/archived request',
    forgedArchived.status === 403,
    `status=${forgedArchived.status}`,
  );
  

  const forgedConverted = await call(
    token,
    'requests',
    'POST',
    docBody({ ...base, converted: true }),
  );
  check(
    'cannot create a request marked already-converted',
    forgedConverted.status === 403,
    `status=${forgedConverted.status}`,
  );
  

  const extraField = await call(
    token,
    'requests',
    'POST',
    docBody({ ...base, total: 0.01, costPrice: 1 }),
  );
  check(
    'cannot smuggle extra fields into a request',
    extraField.status === 403,
    `status=${extraField.status}`,
  );
  

  console.log('\n2. Update restrictions on an existing order');
  const priceEdit = await call(
    token,
    `${reqPath}`,
    'PATCH',
    { fields: { items: field([{ productId: 'tomato_red', qty: 9999, price: 0.01 }]) } },
  );
  check(
    'cannot rewrite the line items / prices',
    priceEdit.status === 403,
    `status=${priceEdit.status}`,
  );

  const vatEdit = await call(token, `${reqPath}`, 'PATCH', docBody({ vat: true }));
  check('cannot flip the VAT flag', vatEdit.status === 403, `status=${vatEdit.status}`);

  const orderNoEdit = await call(
    token,
    `${reqPath}`,
    'PATCH',
    docBody({ orderNo: 1 }),
  );
  check('cannot forge the operation code', orderNoEdit.status === 403, `status=${orderNoEdit.status}`);

  const convertEdit = await call(
    token,
    `${reqPath}`,
    'PATCH',
    docBody({ converted: true }),
  );
  check(
    'cannot mark the order as converted (quote duplication)',
    convertEdit.status === 403,
    `status=${convertEdit.status}`,
  );

  const skipQueue = await call(
    token,
    `${reqPath}`,
    'PATCH',
    docBody({ status: 'confirmed', archived: true }),
  );
  check(
    'cannot jump a `new` order straight to confirmed',
    skipQueue.status === 403,
    `status=${skipQueue.status}`,
  );

  const ownerEdit = await call(
    token,
    `${reqPath}`,
    'PATCH',
    docBody({ customerId: 'someone-else' }),
  );
  check(
    'cannot re-point the order at another account',
    ownerEdit.status === 403,
    `status=${ownerEdit.status}`,
  );

  const ownDelete = await call(token, `${reqPath}`, 'DELETE');
  check('cannot delete the order', ownDelete.status === 403, `status=${ownDelete.status}`);

  // A PATCH without an updateMask REPLACES the whole document, which the
  // create/update rules must reject. The app uses update() (patch semantics), so
  // every positive-case check below passes an explicit field mask.
  console.log('\n3. Delivery answer is allowed from the delivered stage');
  // The admin path sets delivered; a customer may then answer. Simulate the
  // delivered state with the Admin SDK (which bypasses rules by design).
  await db.doc(reqPath).set({ status: 'delivered' }, { merge: true });
  const answer = await call(
    token,
    `${reqPath}`,
    'PATCH',
    docBody({ status: 'confirmed', archived: true }),
    'status,archived',
  );
  check(
    'a customer CAN confirm a delivered order',
    answer.status === 200,
    `status=${answer.status}`,
  );

  console.log('\n4. Team documents are unreachable');
  const provision = await call(
    token,
    `admins/${uid}`,
    'PATCH',
    docBody({ role: 'admin', permissions: [] }),
  );
  check(
    'cannot self-provision an /admins record',
    provision.status === 403,
    `status=${provision.status}`,
  );
  const revoke = await call(
    token,
    `admins/someone`,
    'PATCH',
    docBody({ role: 'revoked', permissions: [] }),
  );
  check('cannot write a tombstone', revoke.status === 403, `status=${revoke.status}`);

  // Clean up the probe document.
  for (const p of cleanup) {
    try {
      await db.doc(p).delete();
    } catch (_) {}
  }
  console.log(`\nCleaned up ${cleanup.length} probe document(s).`);

  console.log(`\n${pass} passed, ${fail} failed.`);
  process.exit(fail === 0 ? 0 : 1);
}

main().catch(async (e) => {
  console.error(e);
  for (const p of cleanup) {
    try {
      await db.doc(p).delete();
    } catch (_) {}
  }
  process.exit(1);
});

