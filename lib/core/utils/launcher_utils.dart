import 'package:url_launcher/url_launcher.dart';

import '../strings/app_strings.dart';
import 'geo_utils.dart';

class LauncherUtils {
  /// Google Maps (the app, when there is one), with directions to [place].
  static Future<bool> directions(GeoPoint place) =>
      launchUrl(place.directionsUrl, mode: LaunchMode.externalApplication);

  /// Google Maps with a pin on [place].
  static Future<bool> showOnMap(GeoPoint place) => launchUrl(place.mapUrl, mode: LaunchMode.externalApplication);

  static Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone));

  static Future<bool> whatsapp(String phone) {
    final number = phone.replaceAll('+', '');
    final text = Uri.encodeComponent(AppStrings.whatsappGreeting);
    return launchUrl(
      Uri.parse('https://wa.me/$number?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }
}
