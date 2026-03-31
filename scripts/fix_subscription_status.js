/**
 * Migration Script: Fix inventory subscriptionActive field
 *
 * Problem: Products were saved with subscriptionActive=true by default
 * even when shop had no active subscription.
 *
 * This script:
 * 1. Reads all subscriptions to find ACTIVE shop IDs
 * 2. Finds all inventory docs where subscriptionActive=true
 * 3. Sets subscriptionActive=false for shops without active subscription
 */

const admin = require('firebase-admin');

const serviceAccount = require('/home/abbos/Downloads/tabassum-marketplace-9821c-firebase-adminsdk-fbsvc-d968d8c26c.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'tabassum-marketplace-9821c',
});

const db = admin.firestore();

async function run() {
  const now = new Date();

  // ── Step 1: Find all shops with ACTIVE subscription ──────────────────────
  console.log('📋 Fetching subscriptions...');
  const subsSnap = await db.collection('subscriptions').get();

  const activeShopIds = new Set();
  subsSnap.docs.forEach((doc) => {
    const d = doc.data();
    const endDate = d.endDate?.toDate?.();
    if (d.status === 'active' && endDate && endDate > now) {
      activeShopIds.add(doc.id); // doc.id === shopId
    }
  });

  console.log(`✅ Active shops: ${activeShopIds.size}`);
  console.log('   IDs:', [...activeShopIds].join(', ') || '(none)');

  // ── Step 2: Find inventory records that say subscriptionActive=true ───────
  console.log('\n📦 Fetching inventory with subscriptionActive=true...');
  const invSnap = await db
    .collection('inventory')
    .where('subscriptionActive', '==', true)
    .get();

  console.log(`   Found: ${invSnap.docs.length} items`);

  // ── Step 3: Update items from inactive shops ──────────────────────────────
  let toFix = [];
  invSnap.docs.forEach((doc) => {
    const shopId = doc.data().shopId;
    if (!activeShopIds.has(shopId)) {
      toFix.push({ ref: doc.ref, shopId, name: doc.data().name });
    }
  });

  console.log(`\n🔧 Items to fix (subscriptionActive → false): ${toFix.length}`);
  toFix.forEach((i) => console.log(`   - [${i.shopId}] ${i.name}`));

  if (toFix.length === 0) {
    console.log('\n✅ Nothing to fix. All data is correct.');
    return;
  }

  // Batch writes (max 500 per batch)
  const BATCH_SIZE = 500;
  for (let i = 0; i < toFix.length; i += BATCH_SIZE) {
    const batch = db.batch();
    toFix.slice(i, i + BATCH_SIZE).forEach(({ ref }) => {
      batch.update(ref, { subscriptionActive: false });
    });
    await batch.commit();
    console.log(`\n✅ Committed batch ${Math.floor(i / BATCH_SIZE) + 1}`);
  }

  console.log(`\n🎉 Done! Fixed ${toFix.length} inventory items.`);
}

run().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
