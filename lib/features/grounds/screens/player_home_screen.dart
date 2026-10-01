import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/search_box_button.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/widgets/settings_button.dart';
import 'venue_list_screen.dart';

/// Player's home
/// Purpose: The first screen of players, who signed up to book sports
/// grounds: the grounds near them and their bookings, apart from the home
/// services customers use. Home services can be added in Settings.
/// Backend: As SportsGroundsSection (venue_directory, ground_booking_list).
/// Done when: A player finds a ground, books it, and finds the booking again.
class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [NotificationsButton(), SettingsButton()]),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => refreshSportsGrounds(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: const [
              SearchBoxButton(hint: AppStrings.searchGrounds, route: Routes.searchGrounds, outlined: true),
              SizedBox(height: 20),
              SportsGroundsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
