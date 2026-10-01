import 'dart:math' as math;

/// A place on the map: a venue's, or the phone's.
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  /// Straight-line ('as the crow flies') distance in kilometres. Roads in
  /// Bhutan wind, so the drive is longer: Google Maps shows that.
  double distanceKm(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) * math.cos(rad(other.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Roughly Bhutan, with a margin: a venue's place must be inside it.
  bool get isInBhutan => latitude >= 26.5 && latitude <= 28.5 && longitude >= 88.5 && longitude <= 92.5;

  /// '27.47280, 89.63900'
  String get label => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// Google Maps with directions to here, from wherever the phone is: it shows
  /// the road, the distance and how long the drive takes. Opens the Google
  /// Maps app when there is one. No API key needed.
  Uri get directionsUrl => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');

  /// Google Maps with a pin here, to check it's the right place.
  Uri get mapUrl => Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

  @override
  bool operator ==(Object other) => other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($label)';
}

/// Finds the coordinates in what a manager pastes: a Google Maps link (long
/// form; short maps.app.goo.gl links are followed first, LocationService), or
/// the coordinates themselves ('27.4728, 89.6390', as Google Maps copies them).
class MapsLink {
  static final _pinned = RegExp(r'!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)'); // the place's own pin
  static final _query = RegExp(r'[?&](?:q|query|ll|destination|center|daddr)=(?:loc:)?(-?\d{1,2}\.\d+),\s*\+?(-?\d{1,3}\.\d+)');
  static final _view = RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)'); // where the map was looking
  static final _bare = RegExp(r'^\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$');
  static final _inPath = RegExp(r'/(-?\d{1,2}\.\d{3,}),\s*\+?(-?\d{1,3}\.\d{3,})');

  /// The short links Google Maps shares, which only say where they lead once followed.
  static bool isShortLink(String text) {
    final host = Uri.tryParse(text.trim())?.host ?? '';
    return host == 'maps.app.goo.gl' || host == 'goo.gl' || host == 'g.co';
  }

  /// Null when [text] has no coordinates.
  static GeoPoint? parse(String text) {
    final decoded = _decode(text.trim());
    for (final pattern in [_pinned, _query, _view, _bare, _inPath]) {
      final match = pattern.firstMatch(decoded);
      if (match == null) continue;
      final point = _point(match);
      if (point != null) return point;
    }
    return null;
  }

  /// Coordinates in a Google Maps web page, for links that lead to one
  /// without them in its address (a page's preview image has the place).
  static GeoPoint? parsePage(String html) {
    final decoded = _decode(html);
    for (final pattern in [_pinned, _query, _view]) {
      final match = pattern.firstMatch(decoded);
      if (match == null) continue;
      final point = _point(match);
      if (point != null) return point;
    }
    return null;
  }

  static GeoPoint? _point(RegExpMatch match) {
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(lat, lng);
  }

  static String _decode(String text) {
    try {
      return Uri.decodeFull(text).replaceAll('&amp;', '&');
    } on ArgumentError {
      return text.replaceAll('%2C', ',').replaceAll('%2c', ',');
    }
  }
}
