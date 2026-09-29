import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/profile.dart';
import '../data/profile_repository.dart';

// Riverpod providers: the logged-in user's profile.
// Screens watch these; these call the repositories in ../data/.

/// C1 greeting, D1 and B1. Invalidate after saving changes.
final myProfileProvider =
    FutureProvider.autoDispose<Profile?>((ref) => ref.watch(profileRepositoryProvider).getMyProfile());
