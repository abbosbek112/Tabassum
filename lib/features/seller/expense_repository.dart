import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/expense_model.dart';

final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepository(ref.watch(firestoreProvider));
});

final expensesByShopProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, shopId) {
  return ref.watch(expenseRepositoryProvider).streamExpensesByShop(shopId);
});

class ExpenseRepository {
  final FirebaseFirestore _db;

  ExpenseRepository(this._db);

  Future<void> addExpense(ExpenseModel expense) async {
    await _db.collection(FirestoreCollections.expenses).add(expense.toMap());
  }

  Stream<List<ExpenseModel>> streamExpensesByShop(String shopId) {
    return _db
        .collection(FirestoreCollections.expenses)
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
