import 'package:url_launcher/url_launcher.dart';

import '../strings/app_strings.dart';

class LauncherUtils {
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
