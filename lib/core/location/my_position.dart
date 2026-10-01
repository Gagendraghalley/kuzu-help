import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/geo_utils.dart';
import 'location_service.dart';

/// Where the phone is: for the dzongkhag shown first ('Your area') and how
/// far away grounds are. The first time the app needs it, it asks to use the
/// location, once; after that it never asks by itself (locate does, when
/// someone taps something that needs it). Null until allowed, and outside
/// Bhutan, where distances to grounds would only be thousands of km (a phone
/// abroad, or a simulator left at its default place). Invalidate to find the
/// phone again (pull to refresh).
final myPositionProvider = AsyncNotifierProvider<MyPosition, GeoPoint?>(MyPosition.new);

class MyPosition extends AsyncNotifier<GeoPoint?> {
  static const askedKey = 'location_asked';

  @override
  Future<GeoPoint?> build() async {
    final service = ref.watch(locationServiceProvider);
    GeoPoint? here;
    if (await _firstTime()) {
      try {
        here = await service.current();
      } on LocationUnavailable {
        here = null; // said no, or no fix: the app carries on without it
      }
    } else {
      here = await service.currentIfAllowed();
    }
    return here != null && here.isInBhutan ? here : null;
  }

  /// True only the first time ever on this phone.
  static Future<bool> _firstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) == true) return false;
      await prefs.setBool(askedKey, true);
      return true;
    } catch (_) {
      return false; // can't remember asking: better not to ask
    }
  }

  /// Asks to use the location if needed, then finds it. Throws
  /// LocationUnavailable (outsideBhutan too), keeping the place it had.
  Future<GeoPoint> locate() async {
    final previous = state.valueOrNull;
    state = const AsyncValue<GeoPoint?>.loading().copyWithPrevious(state);
    try {
      final here = await ref.read(locationServiceProvider).current();
      if (!here.isInBhutan) throw const LocationUnavailable(LocationProblem.outsideBhutan);
      state = AsyncData(here);
      return here;
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
