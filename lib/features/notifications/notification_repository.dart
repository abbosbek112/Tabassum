import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models/notification_model.dart';

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(ref.watch(firestoreProvider));
});

final unreadNotificationsProvider = StreamProvider.family<List<NotificationModel>, String>((ref, shopId) {
  return ref.watch(notificationRepositoryProvider).streamUnreadNotifications(shopId);
});

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository(this._firestore);

  Stream<List<NotificationModel>> streamUnreadNotifications(String shopId) {
    return _firestore
        .collection('notifications')
        .where('shopId', isEqualTo: shopId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotificationModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').add(notification.toMap());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }
}
