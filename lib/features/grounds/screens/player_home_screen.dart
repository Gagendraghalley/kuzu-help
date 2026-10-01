import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_bar_logo.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/widgets/settings_button.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
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
          onRefresh: () => Future.wait([ref.refresh(venuesProvider.future), ref.refresh(myBookingsProvider.future)]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: const [SportsGroundsSection()],
          ),
        ),
      ),
    );
  }
}
