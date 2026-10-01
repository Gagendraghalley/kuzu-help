import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/router/route_names.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/location/location_service.dart';
import 'package:bhutan_services/core/location/my_position.dart';
import 'package:bhutan_services/core/utils/bhutan_time.dart';
import 'package:bhutan_services/core/utils/geo_utils.dart';
import 'package:bhutan_services/core/utils/price_utils.dart';
import 'package:bhutan_services/features/customer/screens/customer_home_screen.dart';
import 'package:bhutan_services/features/grounds/screens/player_home_screen.dart';
import 'package:bhutan_services/features/grounds/widgets/day_strip.dart';
import 'package:bhutan_services/features/grounds/widgets/venue_card.dart';
import 'package:bhutan_services/shared/widgets/choice_sheet.dart';
import 'package:bhutan_services/shared/widgets/dzongkhag_field.dart';
import 'package:bhutan_services/shared/models/ground.dart';
import 'package:bhutan_services/shared/models/ground_booking.dart';
import 'package:bhutan_services/shared/models/regular_booking.dart';
import 'package:bhutan_services/shared/models/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

// Sports grounds: Customer Home's second service. Admins add each ground
// (a venue, with its type and price) and the one person who runs it; that
// ground manager sets its times and answers its bookings; customers book a
// whole time.

/// A booking at the test venue's ground, made once the test has them.
typedef GroundBookingSeed = GroundBooking Function(Venue venue, Ground ground);

/// Changli Futsal (Thimphu), run by [manager] ('tashi'; [me]; null: nobody
/// yet), and Paro Arena in Paro. The test user also books grounds ([roles]:
/// a player too), unless the test says otherwise.
Future<Fakes> openHome(
  WidgetTester tester, {
  String role = UserRole.customer,
  List<String> roles = const [UserRole.player],
  String? manager = 'tashi',
  List<GroundBookingSeed> seeds = const [],
  bool withGround = true,
  GeoPoint? myPosition, // where the phone is, once the app may use it
}) {
  final v = venue(manager: manager);
  final g = ground();
  return pumpApp(
    tester,
    role: role,
    roles: roles,
    loggedIn: true,
    hasPassword: true,
    venues: [v, venue(id: 'venue-paro', name: 'Paro Arena', dzongkhag: 'Paro')],
    grounds: [if (withGround) g, ground(id: 'ground-paro', venueId: 'venue-paro')],
    bookings: [for (final seed in seeds) seed(v, g)],
    myPosition: myPosition,
  );
}

Future<void> openSportsGrounds(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.sportsGrounds).first);
  await tester.pumpAndSettle();
}

Future<void> openSettingsItem(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip(AppStrings.settings));
  await tester.pumpAndSettle();
  await scrollAndTap(tester, find.text(item));
}

/// Slot labels, as the booking screen shows them.
String times(int start, int end) => AppStrings.hoursRange(start, end);

/// Register a ground: Dechen Futsal in Bumthang, Nu 1,200 an hour, run by Sonam Choden.
Future<void> fillInVenueAndManager(WidgetTester tester) async {
  await enterField(tester, AppStrings.venueName, 'Dechen Futsal');
  await tester.pumpAndSettle();
  final dzongkhag = find.byType(DzongkhagField);
  await tester.ensureVisible(dzongkhag);
  await tester.pumpAndSettle();
  await tester.tap(dzongkhag);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bumthang').last);
  await tester.pumpAndSettle();
  await enterField(tester, AppStrings.venuePhone, '17123456');
  await enterField(tester, AppStrings.pricePerHour, '1200');
  await enterField(tester, AppStrings.managerName, 'Sonam Choden');
  await enterField(tester, AppStrings.managerEmail, 'Sonam@Example.com');
  await enterField(tester, AppStrings.managerPhone, '17555555');
  await tester.pumpAndSettle(); // the page stops scrolling to the field typed in
}

/// A request from Karma for tomorrow, 6 to 8 pm.
GroundBooking karmasRequest(Venue v, Ground g) => groundBooking(
    venue: v,
    ground: g,
    start: tomorrowAt(18),
    hours: 2,
    bookedBy: 'karma',
    contactName: 'Karma Wangdi',
    team: 'Changzamtog FC');

void main() {
  group('customers', () {
    testWidgets('Customer Home offers its services; Home services stays the default', (tester) async {
      await openHome(tester);
      expect(find.text(AppStrings.whatDoYouNeed), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);

      await openSportsGrounds(tester);
      expect(find.text(AppStrings.bookAGround), findsOneWidget);
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text(PriceUtils.nu(1000)), findsOneWidget); // From Nu. 1,000 /hour
      expect(find.text('Paro Arena'), findsNothing); // another dzongkhag
      expect(find.text('Plumber'), findsNothing);

      if (showPartyDining) {
        await tapAndSettle(tester, AppStrings.partyDining);
        expect(find.text(AppStrings.partyComingSoon), findsOneWidget);
      } else {
        expect(find.text(AppStrings.partyDining), findsNothing);
      }

      await tapAndSettle(tester, AppStrings.homeServices);
      expect(find.text('Plumber'), findsOneWidget);
    });

    testWidgets('search finds grounds by name or place in any dzongkhag', (tester) async {
      await openHome(tester);
      expect(find.text(AppStrings.searchGrounds), findsNothing); // Home services searches workers
      await openSportsGrounds(tester);

      await tapAndSettle(tester, AppStrings.searchGrounds);
      expect(find.text(AppStrings.typeToSearchGrounds), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'arena');
      await tester.pumpAndSettle();
      expect(find.text('Paro Arena'), findsOneWidget); // Paro, though Thimphu is chosen
      expect(find.text('Changli Futsal'), findsNothing);

      await tester.enterText(find.byType(TextField), 'thimphu');
      await tester.pumpAndSettle();
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text('Paro Arena'), findsNothing);

      await tester.enterText(find.byType(TextField), 'dechen');
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noVenuesNamed('dechen')), findsOneWidget);
    });

    testWidgets('a venue nobody runs yet is not listed', (tester) async {
      await openHome(tester, manager: null);
      await openSportsGrounds(tester);
      expect(find.text('Changli Futsal'), findsNothing);
      expect(find.text(AppStrings.noVenuesYet(everywhere: false)), findsOneWidget);
    });

    testWidgets('a customer books one of the ground\'s evening times', (tester) async {
      final fakes = await openHome(tester);
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      expect(find.text(AppStrings.everyDay), findsOneWidget); // the same times every day
      expect(find.text(AppStrings.hoursShort(18, 20)), findsOneWidget); // '6 – 8 pm'
      await scrollAndTap(tester, find.text(AppStrings.book));
      expect(find.text(AppStrings.bookGround), findsOneWidget);

      await tapAndSettle(tester, AppStrings.tomorrow);
      await scrollAndTap(tester, find.text(times(18, 20)));
      expect(find.text(PriceUtils.nu(3000)), findsOneWidget); // two evening hours at Nu. 1,500
      await enterField(tester, AppStrings.teamName, 'Changzamtog FC');
      await enterField(tester, AppStrings.jobPhone, '17999999');
      await tester.pumpAndSettle(); // the page stops scrolling to the field typed in
      await scrollAndTap(tester, find.text(AppStrings.sendBookingRequest));

      final sent = fakes.bookings.booked.single;
      expect((sent.groundId, sent.start, sent.hours, sent.phone, sent.team),
          ('ground-1', tomorrowAt(18), 2, '+97517999999', 'Changzamtog FC'));
      expect(find.text(AppStrings.bookingRequestSent), findsOneWidget);
    });

    testWidgets('taken times cannot be chosen, and say whether the manager has confirmed them', (tester) async {
      await openHome(tester, seeds: [
        (v, g) => groundBooking(
            venue: v, ground: g, start: tomorrowAt(18), hours: 2, bookedBy: 'karma', status: BookingStatus.confirmed),
        (v, g) => groundBooking(id: 'booking-2', venue: v, ground: g, start: tomorrowAt(20), hours: 2, bookedBy: 'pema'),
      ]);
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await scrollAndTap(tester, find.text(AppStrings.book));
      await tapAndSettle(tester, AppStrings.tomorrow);

      ChoiceChip chip(String label) => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      expect(chip('${times(18, 20)} · Booked').onSelected, isNull);
      expect(chip('${times(20, 22)} · On hold').onSelected, isNull); // waiting for the manager's answer
      expect(chip('${times(19, 21)} · Not available').onSelected, isNull); // runs into both
      expect(chip(times(16, 18)).onSelected, isNotNull);
      expect(chip(times(8, 10)).onSelected, isNotNull);
      expect(find.text(AppStrings.takenTimesNote), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.sendBookingRequest));
      expect(find.text(AppStrings.chooseATime), findsOneWidget);
    });

    testWidgets('a time the manager booked by phone shows as booked to customers', (tester) async {
      await openHome(tester, seeds: [
        (v, g) => groundBooking(
            venue: v,
            ground: g,
            start: tomorrowAt(18),
            hours: 2,
            bookedBy: 'tashi',
            kind: BookingKind.phone,
            contactName: 'Dorji Wangmo',
            status: BookingStatus.confirmed),
      ]);
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await scrollAndTap(tester, find.text(AppStrings.book));
      await tapAndSettle(tester, AppStrings.tomorrow);
      expect(find.text('${times(18, 20)} · Booked'), findsOneWidget);
    });

    testWidgets('a regular booking shows to customers as one, every week', (tester) async {
      final fakes = await openHome(tester);
      final tomorrow = BhutanTime.weekdayOf(BhutanTime.today().add(const Duration(days: 1)));
      fakes.venues.regulars.add(RegularBooking(
          id: 'regular-1', groundId: 'ground-1', weekday: tomorrow, startHour: 18, endHour: 20, name: 'Sonam'));
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await scrollAndTap(tester, find.text(AppStrings.book));
      await tapAndSettle(tester, AppStrings.tomorrow);

      ChoiceChip chip(String label) => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      expect(chip('${times(18, 20)} · ${AppStrings.regularBooking}').onSelected, isNull);
      expect(chip('${times(19, 21)} · Not available').onSelected, isNull);
      expect(chip(times(20, 22)).onSelected, isNotNull);
      expect(find.text('Sonam'), findsNothing); // who it is stays with the manager
    });

    testWidgets('customers can book up to one week ahead, and no further', (tester) async {
      await openHome(tester);
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await scrollAndTap(tester, find.text(AppStrings.book));
      expect(find.text(AppStrings.bookUpToAWeek), findsOneWidget);

      final today = BhutanTime.today();
      await tester.drag(find.byType(DayStrip), const Offset(-1000, 0)); // to the last day
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.dayMonth(today.add(const Duration(days: 6)))), findsOneWidget);
      expect(find.text(AppStrings.dayMonth(today.add(const Duration(days: 7)))), findsNothing);
    });

    testWidgets('if someone else books the time first, the customer is told to choose another', (tester) async {
      final fakes = await openHome(tester);
      fakes.bookings.takeNextBooking = true;
      await openSportsGrounds(tester);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await scrollAndTap(tester, find.text(AppStrings.book));
      await tapAndSettle(tester, AppStrings.tomorrow);
      await scrollAndTap(tester, find.text(times(8, 10)));
      await enterField(tester, AppStrings.jobPhone, '17999999');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(AppStrings.sendBookingRequest));

      expect(find.text(AppStrings.slotTaken), findsOneWidget);
      expect(fakes.bookings.booked, isEmpty);
    });

    testWidgets('a customer cancels an upcoming booking from My bookings', (tester) async {
      final fakes = await openHome(tester, seeds: [
        (v, g) => groundBooking(venue: v, ground: g, start: tomorrowAt(18)),
      ]);
      await openSportsGrounds(tester);
      await tapAndSettle(tester, AppStrings.myBookings);
      expect(find.text(AppStrings.bookingStatusLabel(BookingStatus.pending)), findsOneWidget);

      await scrollAndTap(tester, find.text('Changli Futsal'));
      await tapAndSettle(tester, AppStrings.cancelBooking);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.cancelBooking));
      await tester.pumpAndSettle();

      expect(fakes.bookings.bookings.single.status, BookingStatus.cancelled);
      expect(find.text(AppStrings.bookingStatusChanged(BookingStatus.cancelled)), findsOneWidget);
      expect(find.text(AppStrings.noBookings(upcoming: true)), findsOneWidget);
    });

    testWidgets('after playing, a customer reviews the venue', (tester) async {
      final fakes = await openHome(tester, seeds: [
        (v, g) => groundBooking(
            venue: v, ground: g, start: DateTime.now().subtract(const Duration(days: 2)), status: BookingStatus.confirmed),
      ]);
      await openSportsGrounds(tester);
      await tapAndSettle(tester, AppStrings.myBookings);
      await tapAndSettle(tester, AppStrings.past);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      await tapAndSettle(tester, AppStrings.writeReview);

      expect(find.text(AppStrings.howWasTheGround), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.starsLabel(4)));
      await tester.pump();
      await scrollAndTap(tester, find.text(AppStrings.postReview));
      expect(fakes.venues.reviews.single.rating, 4);
    });
  });

  group('visitors who have not logged in', () {
    /// From Welcome to booking Changli Futsal tomorrow, where 6 to 8 pm is booked.
    Future<void> browseToChangli(WidgetTester tester) async {
      await scrollAndTap(tester, find.text(AppStrings.browseGrounds));
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text(AppStrings.myBookings), findsNothing);

      await scrollAndTap(tester, find.text('Changli Futsal'));
      expect(find.text(AppStrings.everyDay), findsOneWidget); // the same times every day
      expect(find.text(AppStrings.hoursShort(20, 22)), findsOneWidget);
      expect(find.text(AppStrings.reviewVenueAfterPlaying), findsNothing);

      await scrollAndTap(tester, find.text(AppStrings.book));
      await tapAndSettle(tester, AppStrings.tomorrow);
      expect(find.text('${times(18, 20)} · Booked'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, AppStrings.jobPhone), findsNothing);
      // First time here: how to get an account, or log in.
      expect(find.text(AppStrings.logInToBookNote), findsOneWidget);
      expect(find.text(AppStrings.createAccountToBook), findsOneWidget);
      expect(find.text(AppStrings.logInToBook), findsOneWidget);
    }

    /// [role]: the account that logs in or signs up, as the database makes it.
    Future<Fakes> openWelcome(WidgetTester tester, {bool hasPassword = true, String role = UserRole.customer}) {
      final v = venue();
      final g = ground();
      return pumpApp(
        tester,
        role: role,
        hasPassword: hasPassword,
        venues: [v],
        grounds: [g],
        bookings: [
          groundBooking(
              venue: v, ground: g, start: tomorrowAt(18), hours: 2, bookedBy: 'karma', status: BookingStatus.confirmed),
        ],
      );
    }

    /// Back on Changli Futsal's booking screen, now with the form; back leads
    /// to their home: Customer Home, or a player's.
    Future<void> expectBackOnChangli(WidgetTester tester, {bool playerHome = false}) async {
      expect(find.text(AppStrings.bookGround), findsOneWidget);
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, AppStrings.jobPhone), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PlayerHomeScreen), playerHome ? findsOneWidget : findsNothing);
      expect(find.text(AppStrings.whatDoYouNeed), playerHome ? findsNothing : findsOneWidget); // no home services
    }

    testWidgets('a visitor searches grounds and opens one', (tester) async {
      await openWelcome(tester);
      await scrollAndTap(tester, find.text(AppStrings.browseGrounds));

      await tapAndSettle(tester, AppStrings.searchGrounds);
      expect(find.text(AppStrings.typeToSearchGrounds), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'changli');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, 'Changli Futsal');
      expect(find.text(AppStrings.everyDay), findsOneWidget); // its page, with its times
    });

    testWidgets('a customer logs in from a ground, adds sports grounds to the account, and books', (tester) async {
      final fakes = await openWelcome(tester);
      await browseToChangli(tester);

      await scrollAndTap(tester, find.text(AppStrings.logInToBook)); // straight to logging in
      expect(find.widgetWithText(FilledButton, AppStrings.logIn), findsOneWidget);
      expect(find.widgetWithText(TextFormField, AppStrings.name), findsNothing); // not signing up
      await enterField(tester, AppStrings.email, FakeAuthRepository.registeredEmail);
      await enterField(tester, AppStrings.password, FakeAuthRepository.correctPassword);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.logIn));
      await tester.pumpAndSettle();
      expect(fakes.auth.isLoggedIn, isTrue);

      // Home services only so far: sports grounds are their own service.
      expect(find.text(AppStrings.addGroundsNote), findsOneWidget);
      expect(find.widgetWithText(TextFormField, AppStrings.jobPhone), findsNothing);
      await scrollAndTap(tester, find.text(AppStrings.addService(UserRole.player)));
      expect(fakes.profile.addedRoles, [UserRole.player]);
      expect(fakes.profile.profile.roles, containsAll([UserRole.customer, UserRole.player]));
      expect(find.text(AppStrings.serviceAdded(UserRole.player)), findsOneWidget);
      await expectBackOnChangli(tester); // Customer Home, which has both
    });

    testWidgets('an existing player logs in from a ground and books straight away', (tester) async {
      await openWelcome(tester, role: UserRole.player);
      await browseToChangli(tester);
      await scrollAndTap(tester, find.text(AppStrings.logInToBook));
      await enterField(tester, AppStrings.email, FakeAuthRepository.registeredEmail);
      await enterField(tester, AppStrings.password, FakeAuthRepository.correctPassword);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.addGroundsNote), findsNothing);
      await expectBackOnChangli(tester, playerHome: true);
    });

    testWidgets('a new player signs up from a ground, sets a password and comes back to it', (tester) async {
      final fakes = await openWelcome(tester, hasPassword: false, role: UserRole.player);
      await browseToChangli(tester);

      await scrollAndTap(tester, find.text(AppStrings.createAccountToBook)); // straight to signing up
      expect(find.text(AppStrings.signUpTitle), findsOneWidget);
      await enterField(tester, AppStrings.name, 'Pema Dorji');
      await enterField(tester, AppStrings.email, 'pema@example.com');
      await tapAndSettle(tester, AppStrings.sendCode);
      await tester.enterText(find.byType(TextField), '123456'); // the code boxes
      await tester.pumpAndSettle();
      await enterField(tester, AppStrings.password, 'druk-2026');
      await enterField(tester, AppStrings.confirmPassword, 'druk-2026');
      await tapAndSettle(tester, AppStrings.savePassword);

      expect(fakes.auth.sentCodes.single.role, UserRole.player); // a player's account, not a customer's
      await expectBackOnChangli(tester, playerHome: true); // grounds, no home services
    });

    testWidgets('a new player continues with Google from a ground and comes back to it', (tester) async {
      final fakes = await openWelcome(tester, hasPassword: false); // made a customer by the database
      fakes.profile.isNewAccount = true;
      await browseToChangli(tester);

      await scrollAndTap(tester, find.text(AppStrings.createAccountToBook));
      await tapAndSettle(tester, AppStrings.continueWithGoogle);

      expect(fakes.profile.claimedRoles, [UserRole.player]);
      expect(fakes.profile.profile.roles, [UserRole.player]); // a player's account, not a customer's
      expect(find.text(AppStrings.createPasswordTitle), findsNothing);
      await expectBackOnChangli(tester, playerHome: true);
    });

    testWidgets('a customer continues with Google from a ground: sports grounds are added', (tester) async {
      final fakes = await openWelcome(tester); // an account from before
      await browseToChangli(tester);

      await scrollAndTap(tester, find.text(AppStrings.createAccountToBook));
      await tapAndSettle(tester, AppStrings.continueWithGoogle);

      expect(fakes.profile.addedRoles, [UserRole.player]);
      expect(fakes.profile.profile.role, UserRole.customer); // still a customer too
      await expectBackOnChangli(tester);
    });

    testWidgets('signing up from a ground with an email that has an account adds sports grounds to it',
        (tester) async {
      final fakes = await openWelcome(tester); // a customer's account
      await browseToChangli(tester);

      await scrollAndTap(tester, find.text(AppStrings.createAccountToBook));
      await enterField(tester, AppStrings.name, 'Dorji');
      await enterField(tester, AppStrings.email, FakeAuthRepository.registeredEmail);
      await tapAndSettle(tester, AppStrings.sendCode);
      expect(find.text(AppStrings.alreadyRegisteredTitle), findsNothing); // not turned away
      expect(fakes.auth.sentCodes.single.role, isNull); // a log-in code: no new account
      expect(find.text(AppStrings.addingToAccount(UserRole.player)), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();
      expect(fakes.profile.addedRoles, [UserRole.player]);
      expect(fakes.profile.profile.role, UserRole.customer); // still a customer too
      await expectBackOnChangli(tester);
    });

    testWidgets('tapping log in without an account: "Create an account" there signs them up to book', (tester) async {
      await openWelcome(tester);
      await browseToChangli(tester);
      await scrollAndTap(tester, find.text(AppStrings.logInToBook));
      await scrollAndTap(tester, find.text(AppStrings.newHereCreateAccount));

      expect(find.text(AppStrings.signUpTitle), findsOneWidget); // not back to the ground, nor Welcome
      expect(find.widgetWithText(TextFormField, AppStrings.name), findsOneWidget);
    });

    testWidgets('a player adds home services in Settings, and from then on has Customer Home', (tester) async {
      final fakes = await openHome(tester, role: UserRole.player, roles: const []);
      expect(find.byType(PlayerHomeScreen), findsOneWidget);
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text(AppStrings.whatDoYouNeed), findsNothing); // grounds only

      await tester.tap(find.byTooltip(AppStrings.settings));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addService(UserRole.player)), findsNothing); // has it
      expect(find.text(AppStrings.becomeWorker), findsNothing); // a customer's
      await scrollAndTap(tester, find.text(AppStrings.addService(UserRole.customer)));

      expect(fakes.profile.profile.role, UserRole.customer);
      expect(fakes.profile.profile.roles, containsAll([UserRole.customer, UserRole.player]));
      expect(find.text(AppStrings.whatDoYouNeed), findsOneWidget); // Customer Home, with grounds too
    });

    testWidgets('the rest of the app still needs an account', (tester) async {
      await openWelcome(tester);
      await scrollAndTap(tester, find.text(AppStrings.browseGrounds));
      final router = GoRouter.of(tester.element(find.text('Changli Futsal')));
      router.push(Routes.myBookings);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.whatToDo), findsOneWidget); // Welcome
    });
  });

  group('admins', () {
    testWidgets('an admin sees every venue and who runs it', (tester) async {
      await openHome(tester, role: UserRole.admin);
      await openSettingsItem(tester, AppStrings.sportsVenues);
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text('Paro Arena'), findsOneWidget);
      expect(find.text('Tashi Dorji'), findsNWidgets(2));
      expect(find.text('Taking bookings'), findsNWidgets(2));
    });

    testWidgets('an admin registers a venue together with the person who runs it', (tester) async {
      final fakes = await openHome(tester, role: UserRole.admin);
      await openSettingsItem(tester, AppStrings.sportsVenues);
      await tapAndSettle(tester, AppStrings.addVenue);

      final register = find.text(AppStrings.registerVenue);
      await scrollAndTap(tester, register);
      for (final problem in [
        AppStrings.enterVenueName,
        AppStrings.chooseDzongkhag,
        AppStrings.invalidMobile, // the venue's phone; the manager's is optional
        AppStrings.enterPrice,
        AppStrings.enterManagerName,
        AppStrings.invalidEmail,
      ]) {
        expect(find.text(problem), findsOneWidget, reason: problem);
      }
      expect(fakes.venues.accounts, isEmpty);

      await fillInVenueAndManager(tester);
      await scrollAndTap(tester, register);

      final account = fakes.venues.accounts.single;
      expect((account.email, account.fullName, account.phone), ('sonam@example.com', 'Sonam Choden', '+97517555555'));
      expect(fakes.venues.added.single.name, 'Dechen Futsal');
      final ground = fakes.venues.savedGrounds.single; // with it, its type and price
      expect((ground.sport, ground.pricePerHourNu), (Sport.futsal, 1200));
      expect(fakes.venues.venues.last.managerId, 'manager-1');
      expect(find.text(AppStrings.venueRegistered('Dechen Futsal', 'Sonam Choden', 'sonam@example.com', created: true)),
          findsOneWidget);
      // On the new ground: its manager, and its timings to add next.
      expect(find.text('Sonam Choden'), findsOneWidget);
      expect(find.text(AppStrings.noTimingsYet), findsOneWidget);
    });

    testWidgets("an admin's or a worker's email can't run a venue, so no venue is registered", (tester) async {
      final fakes = await openHome(tester, role: UserRole.admin);
      fakes.venues.managerNotAllowed = true;
      await openSettingsItem(tester, AppStrings.sportsVenues);
      await tapAndSettle(tester, AppStrings.addVenue);
      await fillInVenueAndManager(tester);
      await scrollAndTap(tester, find.text(AppStrings.registerVenue));

      expect(find.text(AppStrings.managerNotAllowed), findsOneWidget);
      expect(fakes.venues.added, isEmpty);
    });

    testWidgets('an admin removes a venue\'s manager, and it stops taking bookings', (tester) async {
      final fakes = await openHome(tester, role: UserRole.admin);
      await openSettingsItem(tester, AppStrings.sportsVenues);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      expect(find.text('Tashi Dorji'), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.removeManager));
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.removeManager));
      await tester.pumpAndSettle();

      expect(fakes.venues.managerChanges.single, (venueId: 'venue-1', managerId: null));
      expect(find.text(AppStrings.managerRemoved), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000)); // back to the top
      await tester.pumpAndSettle();
      expect(find.text('No manager yet'), findsOneWidget);
    });
  });

  group('ground managers', () {
    testWidgets('a ground without a type and price yet: its manager adds them, then its timings', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me, withGround: false);
      expect(find.text('Changli Futsal'), findsOneWidget);
      // Nobody can see the ground yet, and it says so.
      expect(find.text(AppStrings.notVisibleYet), findsOneWidget);
      expect(find.text(AppStrings.notVisibleNoGrounds), findsOneWidget);
      expect(find.text(AppStrings.typeAndPriceFirst), findsOneWidget);
      expect(find.text(AppStrings.manageVenue), findsNothing); // no admin tools
      expect(find.text(AppStrings.groundManager), findsNothing);

      await scrollAndTap(tester, find.text(AppStrings.addTypeAndPrice));
      expect(find.text(AppStrings.typeAndPrice), findsOneWidget);
      await enterField(tester, AppStrings.pricePerHour, '1200');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(AppStrings.save));

      final saved = fakes.venues.savedGrounds.single;
      expect((saved.id, saved.sport, saved.pricePerHourNu, saved.eveningPriceNu), (null, Sport.futsal, 1200, null));
      expect(find.text(AppStrings.noTimingsYet), findsOneWidget);
      expect(find.text(AppStrings.setTimings), findsOneWidget);
    });

    testWidgets('the same price all day, unless the manager switches on a night price', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me, withGround: false);
      await scrollAndTap(tester, find.text(AppStrings.addTypeAndPrice));
      await enterField(tester, AppStrings.pricePerHour, '1000');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, AppStrings.eveningPrice), findsNothing);

      await scrollAndTap(tester, find.text(AppStrings.nightPriceLabel));
      await enterField(tester, AppStrings.eveningPrice, '1500'); // from 6 pm, when the lights come on
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(AppStrings.save));

      final saved = fakes.venues.savedGrounds.single;
      expect((saved.pricePerHourNu, saved.eveningPriceNu, saved.eveningFromHour), (1000, 1500, 18));
      expect(find.textContaining(AppStrings.groundPrice(1000, eveningPrice: 1500, eveningFrom: 18)), findsOneWidget);
    });

    testWidgets('a ground manager sets several times a day, Monday to Sunday', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      expect(find.text(AppStrings.everyDay), findsOneWidget);
      expect(find.text(AppStrings.takingBookingsHint), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.setTimings));
      expect(find.text(AppStrings.timingsHint), findsOneWidget);
      expect(find.text(AppStrings.addTime), findsNWidgets(7)); // Monday to Sunday

      // Monday: without 8-10 am (its first time), and with 10 pm to midnight
      // (after its last); then the same every day.
      await tester.tap(find.byTooltip(AppStrings.removeTime).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.addTime).first);
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(AppStrings.copyMondayToAll));
      await scrollAndTap(tester, find.text(AppStrings.saveTimings));

      final saved = fakes.venues.savedSlots.single;
      expect(saved.groundId, 'ground-1');
      for (var day = 0; day < 7; day++) {
        expect([for (final s in saved.slots) if (s.weekday == day) (s.startHour, s.endHour)],
            [(16, 18), (18, 20), (19, 21), (20, 22), (22, 24)], reason: 'day $day');
      }
      expect(find.text(AppStrings.timingsSaved), findsOneWidget);
      expect(find.text(AppStrings.hoursShort(22, 24)), findsOneWidget); // on the ground's home
      expect(find.text(times(8, 10)), findsNothing);
    });

    testWidgets('Edit ground shows the timings, with the way to set them', (tester) async {
      await openHome(tester, role: UserRole.groundManager, manager: me);
      await scrollAndTap(tester, find.text(AppStrings.editVenue));
      expect(find.text(AppStrings.typeAndPrice), findsOneWidget);
      expect(find.text(AppStrings.timings), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.setTimings));
      expect(find.text(AppStrings.timingsHint), findsOneWidget);
    });

    testWidgets('a week with no times at all is not saved', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      await scrollAndTap(tester, find.text(AppStrings.setTimings));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip(AppStrings.removeTime).first); // Monday's five times
        await tester.pumpAndSettle();
      }
      await scrollAndTap(tester, find.text(AppStrings.copyMondayToAll));
      await scrollAndTap(tester, find.text(AppStrings.saveTimings));

      expect(find.text(AppStrings.addAtLeastOneTime), findsOneWidget);
      expect(fakes.venues.savedSlots, isEmpty);
    });

    testWidgets('someone calls: the manager books a time for them, and everyone sees it booked', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      await tapAndSettle(tester, AppStrings.bookings);
      await tapAndSettle(tester, AppStrings.addBooking);
      expect(find.text(AppStrings.phoneBookingHint), findsOneWidget);

      await tapAndSettle(tester, AppStrings.tomorrow);
      await scrollAndTap(tester, find.text(times(18, 20)));
      await scrollAndTap(tester, find.text(AppStrings.bookThisTime));
      expect(find.text(AppStrings.enterCallerName), findsOneWidget); // their name is needed
      expect(fakes.bookings.phoneBookings, isEmpty);

      await enterField(tester, AppStrings.callerName, 'Dorji Wangmo');
      await enterField(tester, AppStrings.callerPhone, '17888888');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(AppStrings.bookThisTime));

      expect(fakes.bookings.phoneBookings.single, (start: tomorrowAt(18), hours: 2, name: 'Dorji Wangmo', phone: '+97517888888'));
      expect(find.text(AppStrings.phoneBooked), findsOneWidget);
      await tapAndSettle(tester, AppStrings.upcoming);
      expect(find.text('Dorji Wangmo'), findsOneWidget);
      expect(find.text(AppStrings.byPhone), findsOneWidget);

      // Cancelled: the time is free again.
      await tapAndSettle(tester, 'Dorji Wangmo');
      await scrollAndTap(tester, find.text(AppStrings.cancelBooking));
      expect(find.text(AppStrings.cancelPhoneBookingMessage), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.cancelBooking));
      await tester.pumpAndSettle();
      expect(fakes.bookings.bookings.single.status, BookingStatus.cancelled);
      expect(find.text(AppStrings.phoneBookingCancelled), findsOneWidget);
    });

    testWidgets('a team plays every week: the manager holds that time for them, edits it, then removes it',
        (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      await tester.dragUntilVisible(
          find.text(AppStrings.noRegularBookings), find.byType(Scrollable).first, const Offset(0, -250));
      expect(find.text(AppStrings.noRegularBookings), findsOneWidget);
      await scrollAndTap(tester, find.text(AppStrings.addRegularBooking));
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, AppStrings.everyWeek)).value, isTrue);
      expect(find.text(AppStrings.phoneBookingHint), findsNothing); // not 'confirmed at once… Booked'

      // The way back, even when the form fills the screen.
      await tester.tap(find.byTooltip(AppStrings.close));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, AppStrings.everyWeek), findsNothing);
      await scrollAndTap(tester, find.text(AppStrings.addRegularBooking));

      final tomorrow = BhutanTime.weekdayOf(BhutanTime.today().add(const Duration(days: 1)));
      await tapAndSettle(tester, AppStrings.tomorrow);
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(18, 20))); // not the home's week behind
      await enterField(tester, AppStrings.callerName, 'Sonam');
      await enterField(tester, AppStrings.teamName, 'Druk FC');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.widgetWithText(FilledButton, AppStrings.addRegularBooking));

      final regular = fakes.venues.regulars.single;
      expect((regular.weekday, regular.startHour, regular.endHour, regular.name, regular.teamName),
          (tomorrow, 18, 20, 'Sonam', 'Druk FC'));
      expect(find.text(AppStrings.regularAdded(tomorrow, 18, 20)), findsOneWidget);
      var every = find.text(AppStrings.everyWeekday(tomorrow, 18, 20));
      expect(every, findsOneWidget); // on the ground's home
      expect(find.text('Sonam · Druk FC'), findsOneWidget);

      // They move to the next day, 8 to 10 pm: held there every week instead.
      final nextDay = (tomorrow + 1) % 7;
      await scrollAndTap(tester, every);
      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.editRegular));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.editRegularTitle), findsOneWidget);
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, AppStrings.weekdayName(nextDay)));
      await scrollAndTap(tester, find.widgetWithText(FilledButton, AppStrings.saveRegular));
      expect(find.text(AppStrings.chooseATime), findsOneWidget); // a new day needs its time
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(20, 22)));
      await enterField(tester, AppStrings.callerName, 'Sonam Dorji');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.widgetWithText(FilledButton, AppStrings.saveRegular));

      final moved = fakes.venues.regulars.single;
      expect((moved.id, moved.weekday, moved.startHour, moved.endHour, moved.name, moved.teamName),
          (regular.id, nextDay, 20, 22, 'Sonam Dorji', 'Druk FC'));
      expect(find.text(AppStrings.regularSaved(nextDay, 20, 22)), findsOneWidget);
      expect(every, findsNothing);
      every = find.text(AppStrings.everyWeekday(nextDay, 20, 22));
      expect(every, findsOneWidget);

      await scrollAndTap(tester, every);
      await tapAndSettle(tester, AppStrings.stopRegular);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.stopRegular));
      await tester.pumpAndSettle();
      expect(fakes.venues.regulars, isEmpty);
      expect(find.text(AppStrings.regularStopped), findsOneWidget);
    });

    testWidgets('a team plays twice a week: both times are held for them every week, added at once', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      await scrollAndTap(tester, find.text(AppStrings.addRegularBooking));
      final today = BhutanTime.today();
      final day1 = BhutanTime.weekdayOf(today.add(const Duration(days: 1)));
      final day2 = BhutanTime.weekdayOf(today.add(const Duration(days: 2)));

      // Tomorrow 6-8 pm, then the day after 8-10 pm: both stay chosen.
      await tapAndSettle(tester, AppStrings.tomorrow);
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(18, 20)));
      await tester.tap(find.text(AppStrings.weekdayName(day2)));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(20, 22)));
      expect(find.text(AppStrings.everyWeekday(day1, 18, 20)), findsOneWidget);
      expect(find.text(AppStrings.everyWeekday(day2, 20, 22)), findsOneWidget);
      expect(find.text(AppStrings.regularMoreDays), findsOneWidget);

      // 7-9 pm that day runs into 8-10 pm, so it takes its place; 4-6 pm is
      // added, then taken off again.
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(19, 21)));
      expect(find.text(AppStrings.everyWeekday(day2, 20, 22)), findsNothing);
      expect(find.text(AppStrings.everyWeekday(day2, 19, 21)), findsOneWidget);
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(20, 22)));
      await scrollAndTap(tester, find.widgetWithText(ChoiceChip, times(16, 18)));
      expect(find.text(AppStrings.everyWeekday(day2, 16, 18)), findsOneWidget);
      await scrollAndTap(tester, find.byTooltip(AppStrings.removeTime).at(1)); // day 2's 4-6 pm, listed second
      expect(find.text(AppStrings.everyWeekday(day2, 16, 18)), findsNothing);

      await enterField(tester, AppStrings.callerName, 'Sonam');
      await enterField(tester, AppStrings.teamName, 'Druk FC');
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.widgetWithText(FilledButton, AppStrings.addRegularBookings(2)));

      expect([for (final r in fakes.venues.regulars) (r.weekday, r.startHour, r.endHour, r.name, r.teamName)],
          [(day1, 18, 20, 'Sonam', 'Druk FC'), (day2, 20, 22, 'Sonam', 'Druk FC')]);
      expect(
          find.text(AppStrings.regularsAdded(
              [AppStrings.everyWeekday(day1, 18, 20), AppStrings.everyWeekday(day2, 20, 22)])),
          findsOneWidget);
      // Both on the ground's home, each to edit or remove on its own.
      expect(find.text(AppStrings.everyWeekday(day1, 18, 20)), findsOneWidget);
      expect(find.text(AppStrings.everyWeekday(day2, 20, 22)), findsOneWidget);
    });

    testWidgets('a booking marked as regular: its day and time are held for them every week', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me, seeds: [
        (v, g) => groundBooking(
            venue: v, ground: g, start: tomorrowAt(18), hours: 2, bookedBy: 'karma', contactName: 'Karma Wangdi',
            team: 'Changzamtog FC', status: BookingStatus.confirmed),
      ]);
      final tomorrow = BhutanTime.weekdayOf(BhutanTime.today().add(const Duration(days: 1)));
      await tapAndSettle(tester, AppStrings.bookings);
      await tapAndSettle(tester, AppStrings.upcoming);
      await tapAndSettle(tester, 'Karma Wangdi · Changzamtog FC');
      await scrollAndTap(tester, find.text(AppStrings.markRegular));
      expect(find.text(AppStrings.markRegularMessage('Karma Wangdi', tomorrow, 18, 20)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.markRegular));
      await tester.pumpAndSettle();

      final regular = fakes.venues.regulars.single;
      expect((regular.weekday, regular.startHour, regular.endHour, regular.name, regular.phone, regular.teamName),
          (tomorrow, 18, 20, 'Karma Wangdi', '+97517999999', 'Changzamtog FC'));
      expect(find.text(AppStrings.regularAdded(tomorrow, 18, 20)), findsOneWidget);

      // The booking says so, and can't be made regular twice.
      await tapAndSettle(tester, 'Karma Wangdi · Changzamtog FC');
      expect(find.text('${AppStrings.regularBooking}: ${AppStrings.everyWeekday(tomorrow, 18, 20)} · Karma Wangdi',
          findRichText: true), findsOneWidget);
      expect(find.text(AppStrings.markRegular), findsNothing);
    });

    testWidgets('a request still waiting for an answer is confirmed before it can be regular', (tester) async {
      await openHome(tester, role: UserRole.groundManager, manager: me, seeds: [karmasRequest]);
      await tapAndSettle(tester, AppStrings.bookings);
      await tapAndSettle(tester, 'Karma Wangdi · Changzamtog FC');
      expect(find.text(AppStrings.confirmBooking), findsOneWidget);
      expect(find.text(AppStrings.markRegular), findsNothing);
    });

    testWidgets('booking records: everyone who booked, with how often and when last', (tester) async {
      await openHome(tester, role: UserRole.groundManager, manager: me, seeds: [
        (v, g) => groundBooking(
            venue: v, ground: g, start: DateTime.now().subtract(const Duration(days: 9)), bookedBy: 'karma',
            contactName: 'Karma Wangdi', status: BookingStatus.completed),
        (v, g) => groundBooking(
            id: 'booking-2', venue: v, ground: g, start: tomorrowAt(18), hours: 2, bookedBy: 'karma',
            contactName: 'Karma Wangdi', status: BookingStatus.confirmed),
        (v, g) => groundBooking(
            id: 'booking-3', venue: v, ground: g, start: tomorrowAt(20), hours: 2, bookedBy: me,
            kind: BookingKind.phone, contactName: 'Dorji', contactPhone: null, status: BookingStatus.confirmed),
      ]);
      await scrollAndTap(tester, find.text(AppStrings.bookingRecords));
      expect(find.text('Karma Wangdi'), findsOneWidget);
      expect(find.textContaining(AppStrings.timesBooked(2)), findsOneWidget);
      expect(find.text('Dorji'), findsOneWidget);
      expect(find.textContaining(AppStrings.timesBooked(1)), findsOneWidget);

      await tapAndSettle(tester, 'Karma Wangdi');
      expect(find.text(AppStrings.call), findsOneWidget); // to reach them
      expect(find.text(AppStrings.bookingTime(tomorrowAt(18), tomorrowAt(20))), findsOneWidget);
    });

    testWidgets('a ground manager confirms a booking request with a message', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me, seeds: [karmasRequest]);
      expect(find.text(AppStrings.requestsToAnswer(1)), findsOneWidget);

      await tapAndSettle(tester, AppStrings.bookings);
      await tapAndSettle(tester, 'Karma Wangdi · Changzamtog FC');
      expect(find.text(AppStrings.call), findsOneWidget); // to reach the customer
      await tapAndSettle(tester, AppStrings.confirmBooking);
      await tester.enterText(find.byType(TextField), 'Please bring your own bibs.');
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.confirmBooking));
      await tester.pumpAndSettle();

      final booking = fakes.bookings.bookings.single;
      expect((booking.status, booking.ownerNote), (BookingStatus.confirmed, 'Please bring your own bibs.'));
      expect(find.text(AppStrings.bookingStatusChanged(BookingStatus.confirmed, byOwner: true)), findsOneWidget);
    });

    testWidgets('the new-booking notification opens the venue\'s bookings', (tester) async {
      await pumpApp(
        tester,
        role: UserRole.groundManager,
        loggedIn: true,
        hasPassword: true,
        venues: [venue(manager: me)],
        grounds: [ground()],
        bookings: [karmasRequest(venue(manager: me), ground())],
        notifications: [
          notice(NotificationTypes.bookingNew, data: {
            'venue_id': 'venue-1',
            'customer_name': 'Karma Wangdi',
            'ground_name': 'Court A',
            'starts_at': tomorrowAt(18).toIso8601String(),
            'hours': 1,
            'status': BookingStatus.pending,
          }),
        ],
      );
      await tester.tap(find.byTooltip(AppStrings.notifications));
      await tester.pumpAndSettle();
      expect(find.textContaining('Court A · '), findsOneWidget);
      expect(find.textContaining('Tap to confirm or reject.'), findsOneWidget);

      await tapAndSettle(tester, 'New booking request from Karma Wangdi');
      expect(find.text(AppStrings.bookings), findsOneWidget);
      expect(find.text('Karma Wangdi · Changzamtog FC'), findsOneWidget);
    });
  });

  group('where grounds are', () {
    const changli = GeoPoint(27.4650, 89.6400);
    const babesa = GeoPoint(27.4380, 89.6520);
    const nearBabesa = GeoPoint(27.4400, 89.6500); // the phone

    /// Changli Futsal and Babesa Futsal, both on the map, in Thimphu.
    Future<Fakes> openGrounds(WidgetTester tester, {bool allowed = false, LocationProblem? problem}) async {
      final fakes = await pumpApp(
        tester,
        roles: const [UserRole.player],
        loggedIn: true,
        hasPassword: true,
        venues: [venue(coordinates: changli), venue(id: 'venue-babesa', name: 'Babesa Futsal', coordinates: babesa)],
        grounds: [ground(), ground(id: 'ground-babesa', venueId: 'venue-babesa')],
        myPosition: nearBabesa,
        locationAllowed: allowed,
      );
      fakes.location.problem = problem;
      await openSportsGrounds(tester);
      return fakes;
    }

    void clearMessages(WidgetTester tester) =>
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();

    List<String> listed(WidgetTester tester) =>
        [for (final card in tester.widgetList<VenueCard>(find.byType(VenueCard))) card.venue.name];
    final toChangli = AppStrings.distanceAway(nearBabesa.distanceKm(changli));
    final toBabesa = AppStrings.distanceAway(nearBabesa.distanceKm(babesa));

    testWidgets('customers see how far each ground is, and the nearest first when they ask', (tester) async {
      final fakes = await openGrounds(tester);
      expect(listed(tester), ['Changli Futsal', 'Babesa Futsal']); // best rated first
      expect(find.text(toBabesa), findsNothing); // not asked for the location yet

      await scrollAndTap(tester, find.text(AppStrings.nearestFirst));
      expect(fakes.location.asked, 1);
      expect(listed(tester), ['Babesa Futsal', 'Changli Futsal']);
      expect(find.text(toBabesa), findsOneWidget);
      expect(find.text(toChangli), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.nearestFirst));
      expect(listed(tester), ['Changli Futsal', 'Babesa Futsal']);
      expect(find.text(toChangli), findsOneWidget); // still shown
    });

    testWidgets('without the location, the list offers to use it; or the offer can be closed', (tester) async {
      final fakes = await openGrounds(tester);
      expect(find.text(AppStrings.distancePrompt), findsOneWidget);

      await tapAndSettle(tester, AppStrings.distancePrompt);
      expect(fakes.location.asked, 1);
      expect(find.text(toBabesa), findsOneWidget);
      expect(find.text(AppStrings.distancePrompt), findsNothing); // done its job
    });

    testWidgets('closing the offer hides it without asking', (tester) async {
      final fakes = await openGrounds(tester);
      await tester.tap(find.byTooltip(AppStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.distancePrompt), findsNothing);
      expect(fakes.location.asked, 0);
      expect(find.text(AppStrings.nearestFirst), findsOneWidget); // still there to ask
    });

    testWidgets('once the app may use the location, distances show straight away', (tester) async {
      final fakes = await openGrounds(tester, allowed: true);
      expect(find.text(toBabesa), findsOneWidget);
      expect(fakes.location.asked, 0);

      await scrollAndTap(tester, find.text('Babesa Futsal'));
      expect(find.text(AppStrings.distanceFromYou(nearBabesa.distanceKm(babesa))), findsOneWidget);
      expect(find.text(AppStrings.directions), findsOneWidget);
    });

    testWidgets("a ground's page offers to show how far it is", (tester) async {
      final fakes = await openGrounds(tester);
      await scrollAndTap(tester, find.text('Babesa Futsal'));
      expect(find.text(AppStrings.directions), findsOneWidget);
      final fromHere = AppStrings.distanceFromYou(nearBabesa.distanceKm(babesa));
      expect(find.text(fromHere), findsNothing);

      await tapAndSettle(tester, AppStrings.showDistance);
      expect(fakes.location.asked, 1);
      expect(find.text(fromHere), findsOneWidget);
      expect(find.text(AppStrings.showDistance), findsNothing);

      await tester.pageBack(); // and on the list too
      await tester.pumpAndSettle();
      expect(find.text(toBabesa), findsOneWidget);
    });

    testWidgets('each card has Directions, straight to Google Maps', (tester) async {
      // Stands in for url_launcher: the links the app opens.
      final opened = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
        opened.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null));

      await openGrounds(tester);
      expect(find.text(AppStrings.directionsShort), findsNWidgets(2));

      await scrollAndTap(tester, find.text(AppStrings.directionsShort).first); // Changli Futsal's
      expect(opened, [changli.directionsUrl.toString()]);
      expect(find.text(AppStrings.directions), findsNothing); // the ground's page didn't open
    });

    group('"Your area"', () {
      const inParo = GeoPoint(27.4280, 89.4160);
      Finder area(String dzongkhag) => find.widgetWithText(PillButton, dzongkhag);

      Future<Fakes> openNearParo(WidgetTester tester, {bool askedBefore = true}) => pumpApp(
            tester,
            roles: const [UserRole.player],
            loggedIn: true,
            hasPassword: true,
            venues: [venue(coordinates: changli), venue(id: 'venue-paro', name: 'Paro Arena', dzongkhag: 'Paro')],
            grounds: [ground(), ground(id: 'ground-paro', venueId: 'venue-paro')],
            myPosition: inParo,
            locationAllowed: askedBefore,
            locationAskedBefore: askedBefore,
          );

      testWidgets('starts as the dzongkhag the phone is in; one picked by hand stays', (tester) async {
        await openNearParo(tester);
        await openSportsGrounds(tester);
        expect(area('Paro'), findsOneWidget);
        expect(find.text('Paro Arena'), findsOneWidget);
        expect(find.text('Changli Futsal'), findsNothing);

        await tester.tap(area('Paro'));
        await tester.pumpAndSettle();
        await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'thim');
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Thimphu')));
        await tester.pumpAndSettle();
        expect(find.text('Changli Futsal'), findsOneWidget);

        // Finding the phone again (pull to refresh) keeps the one picked.
        await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        expect(area('Thimphu'), findsOneWidget);
      });

      testWidgets('the first time, the app asks for the location by itself, once', (tester) async {
        final fakes = await openNearParo(tester, askedBefore: false);
        expect(fakes.location.asked, 1);
        await openSportsGrounds(tester);
        expect(area('Paro'), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(MyPosition.askedKey), isTrue); // not again
      });
    });

    testWidgets('a phone outside Bhutan gets no distances, and is told why', (tester) async {
      const sanFrancisco = GeoPoint(37.785834, -122.406417); // the iOS simulator's 'Apple' location
      final fakes = await pumpApp(
        tester,
        roles: const [UserRole.player],
        loggedIn: true,
        hasPassword: true,
        venues: [venue(coordinates: changli)],
        grounds: [ground()],
        myPosition: sanFrancisco,
        locationAllowed: true,
      );
      await openSportsGrounds(tester);
      expect(find.textContaining('km away'), findsNothing);

      await scrollAndTap(tester, find.text(AppStrings.nearestFirst));
      expect(fakes.location.asked, 1);
      expect(find.text(AppStrings.locationProblem(LocationProblem.outsideBhutan)), findsOneWidget);
      expect(find.textContaining('km away'), findsNothing);
    });

    testWidgets('pulling the list down finds the phone again', (tester) async {
      final fakes = await openGrounds(tester, allowed: true);
      expect(find.text(toBabesa), findsOneWidget);

      fakes.location.position = changli; // walked over to Changli
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.distanceAway(0)), findsOneWidget);
    });

    testWidgets('a customer who said no to location is shown where to allow it', (tester) async {
      final fakes = await openGrounds(tester, problem: LocationProblem.deniedForever);
      await scrollAndTap(tester, find.text(AppStrings.nearestFirst));
      expect(find.text(AppStrings.locationProblem(LocationProblem.deniedForever)), findsOneWidget);
      expect(listed(tester), ['Changli Futsal', 'Babesa Futsal']);

      await tester.tap(find.text(AppStrings.openSettings));
      await tester.pumpAndSettle();
      expect(fakes.location.settingsOpened, [LocationProblem.deniedForever]);
    });

    testWidgets('a ground not on the map has no distance or directions', (tester) async {
      await openHome(tester, myPosition: nearBabesa);
      await openSportsGrounds(tester);
      expect(find.text(AppStrings.nearestFirst), findsNothing);
      expect(find.text(AppStrings.directionsShort), findsNothing);
      await scrollAndTap(tester, find.text('Changli Futsal'));
      expect(find.text(AppStrings.directions), findsNothing);
    });

    testWidgets('a ground manager puts the ground on the map from where they stand', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me, myPosition: changli);
      await scrollAndTap(tester, find.text(AppStrings.editVenue));
      expect(find.text(AppStrings.notOnMapYet), findsOneWidget);

      await scrollAndTap(tester, find.text(AppStrings.useMyLocation));
      expect(find.text(AppStrings.onTheMap), findsOneWidget);
      expect(find.text(changli.label), findsOneWidget);
      await scrollAndTap(tester, find.text(AppStrings.save));
      expect(fakes.venues.venues.first.coordinates, changli);

      // The app may use the location now, so the ground's page shows how far it is.
      clearMessages(tester);
      await scrollAndTap(tester, find.text(AppStrings.seePublicVenue));
      expect(find.text(AppStrings.distanceFromYou(0)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Taken off the map again.
      clearMessages(tester); // 'Saved' would cover the Save button
      await scrollAndTap(tester, find.text(AppStrings.editVenue));
      await scrollAndTap(tester, find.byTooltip(AppStrings.removeFromMap));
      expect(find.text(AppStrings.notOnMapYet), findsOneWidget);
      await scrollAndTap(tester, find.text(AppStrings.save));
      expect(fakes.venues.venues.first.coordinates, isNull);
    });

    testWidgets('or pastes its Google Maps link, which must lead to a place in Bhutan', (tester) async {
      final fakes = await openHome(tester, role: UserRole.groundManager, manager: me);
      fakes.location.links['https://maps.app.goo.gl/Changli'] = changli;
      await scrollAndTap(tester, find.text(AppStrings.editVenue));

      Future<void> paste(String link) async {
        await scrollAndTap(tester, find.text(AppStrings.pasteMapsLink));
        await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), link);
        await tapAndSettle(tester, AppStrings.useLink);
      }

      await paste('https://maps.app.goo.gl/SomewhereElse'); // leads nowhere the app can read
      expect(find.text(AppStrings.mapsLinkNoPlace), findsOneWidget);
      clearMessages(tester);
      await paste('https://maps.google.com/?q=27.7172,85.3240'); // Kathmandu
      expect(find.text(AppStrings.notInBhutan), findsOneWidget);
      clearMessages(tester);
      expect(find.text(AppStrings.notOnMapYet), findsOneWidget);

      await paste('https://maps.app.goo.gl/Changli');
      expect(find.text(changli.label), findsOneWidget);
      await scrollAndTap(tester, find.text(AppStrings.save));
      expect(fakes.venues.venues.first.coordinates, changli);
    });
  });
}
