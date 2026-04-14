import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_category_model.dart';
import '../services/database_service.dart';

final customCategoryProvider = StateNotifierProvider<
    CustomCategoryNotifier, AsyncValue<List<CustomCategory>>>(
  (ref) => CustomCategoryNotifier(),
);

class CustomCategoryNotifier
    extends StateNotifier<AsyncValue<List<CustomCategory>>> {
  final DatabaseService _db = DatabaseService();
  static const _uuid = Uuid();

  CustomCategoryNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _db.getAllCustomCategories();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(CustomCategory cat) async {
    final withId =
        cat.id.isEmpty ? cat.copyWith(id: _uuid.v4()) : cat;
    await _db.insertCustomCategory(withId);
    await load();
  }

  Future<void> update(CustomCategory cat) async {
    await _db.updateCustomCategory(cat);
    await load();
  }

  /// Soft-delete: marks the category as deleted so existing transactions
  /// can still resolve it, but it disappears from creation pickers.
  Future<void> delete(String id) async {
    await _db.softDeleteCustomCategory(id);
    await load();
  }

  /// Hard-delete: permanently removes the category record.
  /// Only call this if you are sure no transactions reference it.
  Future<void> hardDelete(String id) async {
    await _db.hardDeleteCustomCategory(id);
    await load();
  }

  /// Convenience: resolve a [CustomCategory] by id from current state.
  /// Returns null if not found (e.g. the category was hard-deleted).
  CustomCategory? findById(String id) {
    return state.when(
      data: (list) {
        try {
          return list.firstWhere((c) => c.id == id);
        } catch (_) {
          return null;
        }
      },
      loading: () => null,
      error: (_, __) => null,
    );
  }

  /// All non-deleted categories (for pickers).
  List<CustomCategory> get active => state.when(
        data: (list) => list.where((c) => !c.deleted).toList(),
        loading: () => [],
        error: (_, __) => [],
      );
}