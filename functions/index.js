/**
 * Tabassum Market — Firebase Cloud Functions
 *
 * Functions:
 * 1. expireSubscriptions    — daily cron: expire overdue subs & hide inventory
 * 2. onSubscriptionWrite    — realtime: sync inventory when admin activates/deactivates
 * 3. onCommentWritten       — realtime: recalculate shop rating when review added/deleted
 * 4. checkVariantOwnership  — (helper guard in rules is sufficient, extra safety here)
 */

const { onSchedule }     = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin              = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// 1. SCHEDULED — runs every night at 01:00 Tashkent time (UTC+5 = 20:00 UTC)
//    Finds subscriptions where status=='active' AND endDate < now,
//    then sets status='inactive' and cascades subscriptionActive=false on inventory
// ─────────────────────────────────────────────────────────────────────────────
exports.expireSubscriptions = onSchedule(
  {
    schedule: '0 20 * * *',   // 01:00 Tashkent time daily
    timeZone: 'Asia/Tashkent',
    region: 'us-central1',
  },
  async (event) => {
    const now = admin.firestore.Timestamp.now();
    console.log(`[expireSubscriptions] Running at ${new Date().toISOString()}`);

    // Find all active subscriptions whose endDate has passed
    const expiredSnap = await db
      .collection('subscriptions')
      .where('status', '==', 'active')
      .where('endDate', '<', now)
      .get();

    if (expiredSnap.empty) {
      console.log('[expireSubscriptions] No expired subscriptions found.');
      return;
    }

    console.log(`[expireSubscriptions] Found ${expiredSnap.size} expired subscription(s).`);

    for (const subDoc of expiredSnap.docs) {
      const shopId = subDoc.id;
      console.log(`[expireSubscriptions] Expiring shop ${shopId}`);

      // 1. Mark subscription as inactive in subscriptions collection
      await db.collection('subscriptions').doc(shopId).update({
        status: 'inactive',
        expiredAt: now,
      });

      // 2. Mark shop as inactive in shops collection
      await db.collection('shops').doc(shopId).set({ 
        subscriptionActive: false 
      }, { merge: true });

      // 3. Cascade: set subscriptionActive=false on all inventory for this shop
      await _setInventorySubscriptionStatus(shopId, false);

      console.log(`[expireSubscriptions] ✅ Shop ${shopId} expired and inventory hidden.`);
    }

    console.log(`[expireSubscriptions] Done. Expired ${expiredSnap.size} subscriptions.`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. REALTIME — when admin writes to subscriptions/{shopId}
//    Syncs inventory immediately when subscription is activated or deactivated
// ─────────────────────────────────────────────────────────────────────────────
exports.onSubscriptionWrite = onDocumentWritten(
  {
    document: 'subscriptions/{shopId}',
    region: 'us-central1',
  },
  async (event) => {
    const shopId = event.params.shopId;
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    if (!after) {
      // Document deleted: hide all inventory and mark shop as inactive
      console.log(`[onSubscriptionWrite] Subscription deleted for shop ${shopId} → hiding inventory`);
      await db.collection('shops').doc(shopId).set({ subscriptionActive: false }, { merge: true });
      await _setInventorySubscriptionStatus(shopId, false);
      return;
    }

    const beforeEndDate = before?.endDate?.toDate?.() ?? new Date(0);
    const beforeNotExpired = beforeEndDate > new Date();
    const wasActive = (before?.status === 'active') && beforeNotExpired;

    const isActive  = after.status === 'active';
    const endDate   = after.endDate?.toDate?.() ?? new Date(0);
    const notExpired = endDate > new Date();
    const shouldBeActive = isActive && notExpired;

    if (wasActive === shouldBeActive && before !== undefined) {
      console.log(`[onSubscriptionWrite] No change in effective status for shop ${shopId}`);
      return;
    }

    console.log(`[onSubscriptionWrite] Shop ${shopId}: active=${shouldBeActive}`);
    
    // 1. Update the shop document itself
    await db.collection('shops').doc(shopId).set({ 
      subscriptionActive: shouldBeActive 
    }, { merge: true });

    // 2. Cascade to inventory
    await _setInventorySubscriptionStatus(shopId, shouldBeActive);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. REALTIME — when a product comment/review is added or deleted
//    Recalculates the shop's and product's average rating and reviewCount
// ─────────────────────────────────────────────────────────────────────────────
exports.onCommentWritten = onDocumentWritten(
  {
    document: 'product_comments/{commentId}',
    region: 'us-central1',
  },
  async (event) => {
    // Figure out the shopId and productId from the comment (before or after)
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    const shopId = after?.shopId ?? before?.shopId;
    const productId = after?.productId ?? before?.productId;

    if (!shopId) {
      console.warn('[onCommentWritten] No shopId in comment — skipping');
      return;
    }

    console.log(`[onCommentWritten] Recalculating rating for shop ${shopId} and product ${productId}`);

    // Fetch ALL comments for this shop
    const shopCommentsSnap = await db
      .collection('product_comments')
      .where('shopId', '==', shopId)
      .get();

    const shopRatings = shopCommentsSnap.docs
      .map(d => d.data().rating)
      .filter(r => typeof r === 'number' && r > 0);

    const shopReviewCount = shopRatings.length;
    const shopAvgRating = shopReviewCount > 0
      ? Math.round((shopRatings.reduce((a, b) => a + b, 0) / shopReviewCount) * 10) / 10
      : 0;

    const batch = db.batch();
    batch.update(db.collection('shops').doc(shopId), {
      rating: shopAvgRating,
      reviewCount: shopReviewCount,
    });

    if (productId) {
      // Calculate specifically for this product
      const productRatings = shopCommentsSnap.docs
        .filter(d => d.data().productId === productId)
        .map(d => d.data().rating)
        .filter(r => typeof r === 'number' && r > 0);

      const productReviewCount = productRatings.length;
      const productAvgRating = productReviewCount > 0
        ? Math.round((productRatings.reduce((a, b) => a + b, 0) / productReviewCount) * 10) / 10
        : 0;

      // Ensure the inventory document exists before updating
      const productRef = db.collection('inventory').doc(productId);
      const productDoc = await productRef.get();
      if (productDoc.exists) {
        batch.update(productRef, {
          rating: productAvgRating,
          reviewCount: productReviewCount,
        });
        console.log(`[onCommentWritten] ✅ Product ${productId}: rating=${productAvgRating}, reviews=${productReviewCount}`);
      } else {
         console.warn(`[onCommentWritten] Product ${productId} not found!`);
      }
    }

    await batch.commit();
    console.log(`[onCommentWritten] ✅ Shop ${shopId}: rating=${shopAvgRating}, reviews=${shopReviewCount}`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — batch-updates subscriptionActive on all inventory for a shop
// ─────────────────────────────────────────────────────────────────────────────
async function _setInventorySubscriptionStatus(shopId, active) {
  const BATCH_SIZE = 400;
  let lastDoc = null;

  do {
    let query = db
      .collection('inventory')
      .where('shopId', '==', shopId)
      .limit(BATCH_SIZE);

    // When activating: only activate items that are explicitly status='active'
    // (don't resurrect deleted/archived products)
    if (active) {
      query = query.where('status', '==', 'active');
    }

    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach(doc => {
      batch.update(doc.ref, { subscriptionActive: active });
    });
    await batch.commit();

    console.log(`[_setInventoryStatus] Shop ${shopId}: updated ${snap.size} items (active=${active})`);
    lastDoc = snap.docs.length === BATCH_SIZE ? snap.docs[snap.docs.length - 1] : null;
  } while (lastDoc);
}
