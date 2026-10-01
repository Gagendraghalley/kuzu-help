import 'package:flutter/material.dart';

import '../../core/location/location_service.dart';
import '../../core/strings/app_strings.dart';

/// Says why the phone's location couldn't be used, with a way to Settings
/// when only they can fix it. It goes by itself, like other messages: one
/// with a button would otherwise stay, even on the screens after this one.
void showLocationProblem(BuildContext context, LocationService service, LocationProblem problem) {
  final fixInSettings = problem == LocationProblem.serviceOff || problem == LocationProblem.deniedForever;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    persist: false,
    duration: const Duration(seconds: 6),
    content: Text(AppStrings.locationProblem(problem)),
    action: fixInSettings
        ? SnackBarAction(label: AppStrings.openSettings, onPressed: () => service.openSettings(problem))
        : null,
  ));
}
