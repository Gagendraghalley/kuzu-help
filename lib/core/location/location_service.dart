import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/geo_utils.dart';

/// Why the phone's location isn't available.
enum LocationProblem {
  serviceOff, // Location is off for the whole phone
  denied, // the person said no this time
  deniedForever, // only Settings can allow it now
  unavailable, // allowed, but no fix came (indoors, timed out)
  outsideBhutan, // found, but too far away for distances to grounds to mean anything
}

class LocationUnavailable implements Exception {
  final LocationProblem problem;
  const LocationUnavailable(this.problem);

  @override
  String toString() => 'LocationUnavailable($problem)';
}

/// The phone's location (geolocator), and the coordinates behind a pasted
/// Google Maps link. Only asks for permission in [current], when the person
/// has just tapped something that needs it.
class LocationService {
  /// Where the phone is, if the app may already use its location; null
  /// otherwise. Never asks.
  Future<GeoPoint?> currentIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition(); // no fix in time: where it last was
      }
      return position == null ? null : GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Where the phone is, asking for permission first if needed: to about
  /// 10 m, or as closely as the phone can when [precise] (marking a
  /// ground's place). Throws [LocationUnavailable].
  Future<GeoPoint> current({bool precise = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable(LocationProblem.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(LocationProblem.deniedForever);
    }
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
      throw const LocationUnavailable(LocationProblem.denied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: precise ? LocationAccuracy.best : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationUnavailable(LocationProblem.unavailable);
    }
  }

  /// The phone's Location settings when it's off; otherwise this app's
  /// settings, where location can be allowed.
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// The coordinates in a pasted Google Maps link or in typed coordinates;
  /// null when there are none. Short links (maps.app.goo.gl) are followed
  /// to where they lead, which needs the internet.
  Future<GeoPoint?> resolveMapsLink(String text) async {
    final direct = MapsLink.parse(text);
    if (direct != null || !MapsLink.isShortLink(text)) return direct;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      var url = Uri.parse(text.trim());
      for (var hop = 0; hop < 6; hop++) {
        final request = await client.getUrl(url)..followRedirects = false;
        final response = await request.close().timeout(const Duration(seconds: 15));
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (response.isRedirect && location != null) {
          await response.drain<void>();
          url = url.resolve(location);
          final found = MapsLink.parse(url.toString());
          if (found != null) return found;
          continue;
        }
        // The last page: its preview image says where the place is.
        final page = await response
            .transform(const Utf8Decoder(allowMalformed: true))
            .take(64) // the start of the page is enough
            .join()
            .timeout(const Duration(seconds: 15));
        return MapsLink.parsePage(page);
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
