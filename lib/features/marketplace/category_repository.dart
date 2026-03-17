import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/category_model.dart';

final categoryRepositoryProvider = Provider((ref) {
  return CategoryRepository(ref.watch(firestoreProvider));
});

final rootCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).streamRootCategories();
});

final popularCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).streamPopularCategories();
});

final subcategoriesProvider = StreamProvider.family<List<CategoryModel>, String>((ref, parentId) {
  return ref.watch(categoryRepositoryProvider).streamSubcategories(parentId);
});

final categoryProvider = StreamProvider.family<CategoryModel?, String>((ref, id) {
  return ref.watch(categoryRepositoryProvider).streamCategory(id);
});

final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).streamAllCategories();
});

class CategoryRepository {
  final FirebaseFirestore _firestore;

  CategoryRepository(this._firestore);

  Stream<List<CategoryModel>> streamRootCategories() {
    return _firestore
        .collection(FirestoreCollections.categories)
        .where('parentId', isNull: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<CategoryModel>> streamAllCategories() {
    return _firestore
        .collection(FirestoreCollections.categories)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<CategoryModel>> streamPopularCategories() {
    return _firestore
        .collection(FirestoreCollections.categories)
        .where('isPopular', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<CategoryModel>> streamSubcategories(String parentId) {
    return _firestore
        .collection(FirestoreCollections.categories)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList());
  }

  Stream<CategoryModel?> streamCategory(String id) {
    return _firestore
        .collection(FirestoreCollections.categories)
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? CategoryModel.fromMap(snap.id, snap.data()!) : null);
  }

  Future<void> _seedIfEmpty() async {
    final snap = await _firestore.collection(FirestoreCollections.categories).limit(1).get();
    if (snap.docs.isEmpty) {
      // Seed initial structure
      final batch = _firestore.batch();
      final coll = _firestore.collection(FirestoreCollections.categories);
      
      for (final cat in _initialCategories) {
        final doc = coll.doc(cat.id);
        batch.set(doc, cat.toMap());
      }
      await batch.commit();
    }
  }

  /// Expose the seed method so UI can trigger it safely if needed initially
  Future<void> seedInitialCategories() => _seedIfEmpty();
}

final _initialCategories = <CategoryModel>[
  // Root level
  const CategoryModel(id: 'clothes', name: 'clothes', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'electronics', name: 'electronics', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'home', name: 'home_garden', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'beauty', name: 'beauty', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'toys', name: 'toys', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'perfumery', name: 'perfumery', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'auto', name: 'auto_parts', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'tools', name: 'tools', gender: GenderCategory.unisex, parentId: null, isPopular: true),
  const CategoryModel(id: 'sport', name: 'sport_hobby', gender: GenderCategory.unisex, parentId: null, isPopular: true),

  // Clothes Subcategories
  const CategoryModel(id: 'clothes_men', name: 'men_clothes', gender: GenderCategory.male, parentId: 'clothes'),
  const CategoryModel(id: 'clothes_women', name: 'women_clothes', gender: GenderCategory.female, parentId: 'clothes'),
  const CategoryModel(id: 'clothes_shoes', name: 'shoes', gender: GenderCategory.unisex, parentId: 'clothes'),

  // Electronics
  const CategoryModel(id: 'elec_phones', name: 'phones', gender: GenderCategory.unisex, parentId: 'electronics'),
  const CategoryModel(id: 'elec_laptops', name: 'laptops', gender: GenderCategory.unisex, parentId: 'electronics'),

  // Toys
  const CategoryModel(id: 'toys_plush', name: 'toys_kids', gender: GenderCategory.unisex, parentId: 'toys'),
  const CategoryModel(id: 'toys_edu', name: 'educational_toys', gender: GenderCategory.unisex, parentId: 'toys'),

  // Perfumery
  const CategoryModel(id: 'perf_men', name: 'perfume_men', gender: GenderCategory.male, parentId: 'perfumery'),
  const CategoryModel(id: 'perf_women', name: 'perfume_women', gender: GenderCategory.female, parentId: 'perfumery'),

  // Auto
  const CategoryModel(id: 'auto_spare', name: 'spare_parts', gender: GenderCategory.unisex, parentId: 'auto'),
  const CategoryModel(id: 'auto_acc', name: 'car_accessories', gender: GenderCategory.unisex, parentId: 'auto'),

  // Tools
  const CategoryModel(id: 'tools_power', name: 'power_tools', gender: GenderCategory.unisex, parentId: 'tools'),
  const CategoryModel(id: 'tools_hand', name: 'hand_tools', gender: GenderCategory.unisex, parentId: 'tools'),
];
