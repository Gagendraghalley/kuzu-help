import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dzongkhags.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/worker_listing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/directory_repository.dart';

// Riverpod providers: Selected dzongkhag (remembered), selected category, sort order and search results.
// Screens watch these; these call the repositories in ../data/.

/// C1 (and B2): active service categories.
final categoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>(
    (ref) => ref.watch(directoryRepositoryProvider).getCategories());

/// C1/C2: the dzongkhag customers search in, or [kAllDzongkhags]; remembered on
/// the phone. Until they pick one it is their own dzongkhag, or Thimphu.
final selectedDzongkhagProvider =
    AsyncNotifierProvider<SelectedDzongkhag, String>(SelectedDzongkhag.new);

class SelectedDzongkhag extends AsyncNotifier<String> {
  static const _key = 'selected_dzongkhag';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == kAllDzongkhags || kDzongkhags.contains(saved)) return saved!;
    try {
      final own = (await ref.read(profileRepositoryProvider).getMyProfile())?.dzongkhag;
      if (own != null && kDzongkhags.contains(own)) return own;
    } catch (_) {
      // Offline: use the default. The search itself shows the error.
    }
    return AppConstants.defaultDzongkhag;
  }

  Future<void> select(String dzongkhag) async {
    state = AsyncData(dzongkhag);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dzongkhag);
  }
}

/// C1 -> C2: the category tapped on Customer Home.
final selectedCategoryProvider = StateProvider<ServiceCategory?>((ref) => null);

/// C2 sort order.
final workerSortProvider = StateProvider<WorkerSort>((ref) => WorkerSort.rating);

/// C2 'Available now': only workers taking work.
final availableOnlyProvider = StateProvider<bool>((ref) => false);

/// C1 search by name: what's typed, and the workers found.
final nameSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final nameSearchResultsProvider = FutureProvider.autoDispose<List<WorkerListing>>((ref) {
  final query = ref.watch(nameSearchProvider).trim();
  if (query.length < 2) return const [];
  return ref.watch(directoryRepositoryProvider).searchByName(query);
});

/// C2 results: approved workers for the selected category and dzongkhag.
/// Admins also see workers waiting for approval, so they can find new sign-ups.
final workerSearchProvider = FutureProvider.autoDispose<List<WorkerResult>>((ref) async {
  final category = ref.watch(selectedCategoryProvider);
  final sort = ref.watch(workerSortProvider);
  final repo = ref.watch(directoryRepositoryProvider);
  final dzongkhag = ref.watch(selectedDzongkhagProvider.future);
  final profile = ref.watch(myProfileProvider.future);
  if (category == null) return const [];
  final area = await dzongkhag;
  return repo.searchWorkers(
    categoryId: category.id,
    dzongkhag: area == kAllDzongkhags ? null : area,
    sort: sort,
    includeUnlisted: (await profile)?.role == UserRole.admin,
  );
});
