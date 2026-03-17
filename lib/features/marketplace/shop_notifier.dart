import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/shop_model.dart';
import 'shop_repository.dart';

class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDoc;

  PaginationState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDoc,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDoc,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}

class ShopPaginationNotifier extends StateNotifier<PaginationState<ShopModel>> {
  final ShopRepository _repository;
  
  ShopPaginationNotifier(this._repository) : super(PaginationState(items: [])) {
    fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final snapshot = await _repository.fetchShopsPaginated(
        lastDocument: state.lastDoc,
        limit: 12,
      );

      final newItems = snapshot.docs.map((d) => ShopModel.fromMap(d.id, d.data())).toList();
      
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: newItems.length == 12,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDoc,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = PaginationState(items: []);
    fetchNextPage();
  }
}

final shopPaginationProvider = StateNotifierProvider<ShopPaginationNotifier, PaginationState<ShopModel>>((ref) {
  return ShopPaginationNotifier(ref.watch(shopRepositoryProvider));
});
