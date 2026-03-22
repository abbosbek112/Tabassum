import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(db: ref.watch(firestoreProvider));
});

class SubscriptionModel {
  final String shopId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // active/inactive

  const SubscriptionModel({
    required this.shopId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory SubscriptionModel.fromMap(String shopId, Map<String, dynamic> map) {
    DateTime readDt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SubscriptionModel(
      shopId: shopId,
      startDate: readDt(map['startDate']),
      endDate: readDt(map['endDate']),
      status: (map['status'] as String?) ?? 'inactive',
    );
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
      };
}

class SubscriptionHistoryModel {
  final String id;
  final String shopId;
  final DateTime activatedAt;
  final DateTime endDate;
  final Duration duration;
  final int amount; // Payment amount
  final String? notes;

  const SubscriptionHistoryModel({
    required this.id,
    required this.shopId,
    required this.activatedAt,
    required this.endDate,
    required this.duration,
    required this.amount,
    this.notes,
  });

  factory SubscriptionHistoryModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SubscriptionHistoryModel(
      id: id,
      shopId: (map['shopId'] as String?) ?? '',
      activatedAt: readDt(map['activatedAt']),
      endDate: readDt(map['endDate']),
      duration: Duration(days: (map['days'] as int?) ?? 0),
      amount: (map['amount'] as int?) ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'activatedAt': activatedAt,
        'endDate': endDate,
        'days': duration.inDays,
        'amount': amount,
        'notes': notes,
      };
}

class SubscriptionRepository {
  final FirebaseFirestore db;
  SubscriptionRepository({required this.db});

  Stream<SubscriptionModel?> streamSubscription(String shopId) {
    return db.collection(FirestoreCollections.subscriptions).doc(shopId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return null;
      return SubscriptionModel.fromMap(d.id, data);
    });
  }

  Stream<bool> streamIsActive(String shopId) {
    return streamSubscription(shopId).map((s) {
      if (s == null) return false;
      return s.status == 'active' && s.endDate.isAfter(DateTime.now());
    });
  }

  /// Activates subscription, records history, and marks all shop inventory as visible.
  Future<void> activate({
    required String shopId,
    required Duration duration,
    required int amount,
    String? notes,
  }) async {
    final now = DateTime.now();
    final end = now.add(duration);

    final batch = db.batch();

    // 1. Update subscription document
    batch.set(
      db.collection(FirestoreCollections.subscriptions).doc(shopId),
      SubscriptionModel(shopId: shopId, startDate: now, endDate: end, status: 'active').toMap(),
      SetOptions(merge: true),
    );

    // 2. Add History Record
    batch.set(
      db.collection(FirestoreCollections.subscriptionHistory).doc(),
      SubscriptionHistoryModel(
        id: '',
        shopId: shopId,
        activatedAt: now,
        endDate: end,
        duration: duration,
        amount: amount,
        notes: notes,
      ).toMap(),
    );

    await batch.commit();

    // 3. Cascade: mark all inventory of this shop as active
    await _updateInventorySubscriptionStatus(shopId, active: true);
  }

  /// Expires subscription and hides all shop inventory from the marketplace.
  Future<void> expire(String shopId) async {
    // 1. Update subscription document
    await db.collection(FirestoreCollections.subscriptions).doc(shopId).set(
      {'status': 'inactive', 'endDate': DateTime.now()},
      SetOptions(merge: true),
    );

    // 2. Cascade: mark all inventory of this shop as inactive
    await _updateInventorySubscriptionStatus(shopId, active: false);
  }

  /// Streams history for all shops or a specific one, ordered by date.
  Stream<List<SubscriptionHistoryModel>> streamSubscriptionHistory({String? shopId}) {
    Query query = db.collection(FirestoreCollections.subscriptionHistory).orderBy('activatedAt', descending: true);
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((q) => q.docs.map((d) => SubscriptionHistoryModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  /// Batch-updates `subscriptionActive` on all inventory documents for [shopId].
  Future<void> _updateInventorySubscriptionStatus(String shopId, {required bool active}) async {
    const batchSize = 400; // Firestore batch limit is 500
    QuerySnapshot<Map<String, dynamic>> snapshot;
    DocumentSnapshot? lastDoc;

    do {
      Query<Map<String, dynamic>> query = db
          .collection(FirestoreCollections.inventory)
          .where('shopId', isEqualTo: shopId)
          .limit(batchSize);

      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'subscriptionActive': active});
      }
      await batch.commit();

      lastDoc = snapshot.docs.last;
    } while (snapshot.docs.length == batchSize);
  }
}
