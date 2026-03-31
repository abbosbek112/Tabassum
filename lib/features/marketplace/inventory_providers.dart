import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/inventory_model.dart';
import 'inventory_repository.dart';

class PaginatedInventoryState {
  final List<InventoryModel> items;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;

  PaginatedInventoryState({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    this.lastDoc,
  });

  PaginatedInventoryState copyWith({
    List<InventoryModel>? items,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
  }) {
    return PaginatedInventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}

class PaginatedInventoryNotifier extends StateNotifier<PaginatedInventoryState> {
  final InventoryRepository _repository;
  final String? categoryId;
  final String? shopId;

  PaginatedInventoryNotifier(
    this._repository, {
    this.categoryId,
    this.shopId,
  }) : super(PaginatedInventoryState(
          items: [],
          isLoading: false,
          hasMore: true,
        )) {
    loadNextBatch();
  }

  Future<void> loadNextBatch() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final snapshot = await _repository.getInventoryBatch(
        categoryId: categoryId,
        shopId: shopId,
        startAfter: state.lastDoc,
        limit: 10,
      );

      final newItems = snapshot.docs
          .map((d) => InventoryModel.fromMap(d.id, d.data()))
          .toList();
      
      // Sort client-side safely
      newItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: snapshot.docs.length == 10,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDoc,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = PaginatedInventoryState(
      items: [],
      isLoading: false,
      hasMore: true,
    );
    await loadNextBatch();
  }
}

final paginatedInventoryProvider = StateNotifierProvider.family<
    PaginatedInventoryNotifier, PaginatedInventoryState, String?>((ref, categoryId) {
  return PaginatedInventoryNotifier(
    ref.watch(inventoryRepositoryProvider),
    categoryId: categoryId,
  );
});

final shopPaginatedInventoryProvider = StateNotifierProvider.family<
    PaginatedInventoryNotifier, PaginatedInventoryState, String>((ref, shopId) {
  return PaginatedInventoryNotifier(
    ref.watch(inventoryRepositoryProvider),
    shopId: shopId,
  );
});
