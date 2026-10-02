import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/utils/price_utils.dart';
import 'package:bhutan_services/shared/models/subscription.dart';
import 'package:bhutan_services/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Ground subscriptions (supabase/updates.sql, section 14): a free month for
// each new ground, then a payment each month that an admin records, one
// month at a time. Only admins change them; the ground's manager reads them.
// Once one has ended, players can't find the ground.

/// Changli Futsal (Thimphu), run by [manager] (the test user unless said),
/// on [subscription] (a free trial with 21 days left); and Paro Arena, paid
/// for 15 more days.
Future<Fakes> openGrounds(
  WidgetTester tester, {
  String role = UserRole.groundManager,
  List<String> roles = const [],
  String? manager = me,
  VenueSubscription? subscription,
  List<SubscriptionPeriod> periods = const [],
  List<Map<String, dynamic>> notices = const [],
}) =>
    pumpApp(
      tester,
      role: role,
      roles: roles,
      loggedIn: true,
      hasPassword: true,
      venues: [
        venue(manager: manager, subscription: subscription),
        venue(
            id: 'venue-paro',
            name: 'Paro Arena',
            dzongkhag: 'Paro',
            subscription: subscriptionFor(daysLeft: 15, kind: SubscriptionKind.paid)),
      ],
      grounds: [ground(), ground(id: 'ground-paro', venueId: 'venue-paro')],
      subscriptionPeriods: periods,
      notifications: [
        for (final (i, data) in notices.indexed) notice(data['type'] as String, id: 'n$i', data: data),
      ],
    );

/// The month (or free time) that ends when [s] does.
SubscriptionPeriod periodOf(VenueSubscription s, {String kind = SubscriptionKind.trial, int? amountNu}) =>
    SubscriptionPeriod(
      id: 'period-0',
      venueId: 'venue-1',
      kind: kind,
      startsAt: s.endsAt.subtract(const Duration(days: 30)),
      endsAt: s.endsAt,
      amountNu: amountNu,
      paymentMethod: amountNu == null ? null : BillingMethod.mbob,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

Future<void> openSettingsItem(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip(AppStrings.settings));
  await tester.pumpAndSettle();
  await scrollAndTap(tester, find.text(item));
}

/// Admin: Settings -> Sports grounds -> Changli Futsal -> its Subscription page.
Future<void> openChangliSubscription(WidgetTester tester) async {
  await openSettingsItem(tester, AppStrings.sportsVenues);
  await tapAndSettle(tester, 'Changli Futsal');
  await scrollAndTap(tester, find.text(AppStrings.subscription));
}

/// Whether the button showing [label] can be tapped.
bool isEnabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(
        find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)))
    .enabled;

/// The Subscription page's 'Monthly fee: Nu. 1,500 a month' (one rich text).
Finder feeRow(int fee) => find.text('${AppStrings.monthlyFee}: ${AppStrings.feePerMonth(fee)}', findRichText: true);

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(PrimaryButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('ground managers', () {
    testWidgets('see their free trial and billing on the Subscription page, but nothing to change', (tester) async {
      final s = subscriptionFor(daysLeft: 21);
      await openGrounds(tester, subscription: s, periods: [periodOf(s)]);
      // With plenty of time left, it waits below the bookings and timings.
      await scrollAndTap(tester, find.text(AppStrings.subscription));

      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.trial, s.lastDay)), findsOneWidget);
      expect(find.text(AppStrings.listedUntil(s.lastDay)), findsOneWidget);
      expect(feeRow(1500), findsOneWidget);
      expect(find.text('mBoB 200123456 (Kuzu Help)'), findsOneWidget); // how to pay, from Billing settings
      expect(find.text(AppStrings.subscriptionManagerNote), findsOneWidget);
      await tester.dragUntilVisible(
          find.text(AppStrings.subscriptionKindLabel(SubscriptionKind.trial)), find.byType(Scrollable).first,
          const Offset(0, -250));
      expect(find.text(AppStrings.billingHistory), findsOneWidget);
      // Only admins change subscriptions.
      for (final adminOnly in [AppStrings.recordPayment, AppStrings.giveFreeTime, AppStrings.changeFee]) {
        expect(find.text(adminOnly), findsNothing, reason: adminOnly);
      }
    });

    testWidgets('in its last days, the subscription moves to the top and says what to pay', (tester) async {
      final s = subscriptionFor(daysLeft: 3);
      await openGrounds(tester, subscription: s);
      expect(find.text(AppStrings.subscriptionDaysLeft(SubscriptionKind.trial, 3)), findsOneWidget);
      expect(find.text(AppStrings.payNextMonth(1500)), findsOneWidget);
      expect(find.text('Taking bookings'), findsWidgets); // still listed meanwhile

      await tapAndSettle(tester, AppStrings.subscription);
      expect(find.text(AppStrings.payNextMonth(1500)), findsOneWidget);
    });

    testWidgets('once it has ended, the manager is told the ground is hidden, and why', (tester) async {
      final s = subscriptionFor(daysLeft: -2);
      await openGrounds(tester, subscription: s);
      expect(find.text('Hidden'), findsOneWidget);
      expect(find.text(AppStrings.subscriptionEndedHint), findsOneWidget);
      expect(find.text(AppStrings.subscriptionEnded), findsOneWidget);
      expect(find.text(AppStrings.payToListAgain(1500)), findsOneWidget);

      await tapAndSettle(tester, AppStrings.subscription);
      expect(find.text(AppStrings.endedOn(s.lastDay)), findsOneWidget);
    });
  });

  testWidgets("players can't find a ground whose subscription has ended", (tester) async {
    await openGrounds(tester,
        role: UserRole.customer,
        roles: [UserRole.player],
        manager: 'tashi',
        subscription: subscriptionFor(daysLeft: -1));
    await tapAndSettle(tester, AppStrings.sportsGrounds);
    expect(find.text('Changli Futsal'), findsNothing);
    expect(find.text(AppStrings.noVenuesYet(everywhere: false)), findsOneWidget);

    await tapAndSettle(tester, AppStrings.searchGrounds);
    await tester.enterText(find.byType(TextField), 'changli');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noVenuesNamed('changli')), findsOneWidget);
  });

  group('admins', () {
    testWidgets("see each ground's subscription on the list; one that ended is hidden", (tester) async {
      final s = subscriptionFor(daysLeft: -2);
      await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s);
      await openSettingsItem(tester, AppStrings.sportsVenues);

      expect(find.text(AppStrings.subscriptionEnded), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
      final paro = subscriptionFor(daysLeft: 15, kind: SubscriptionKind.paid);
      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.paid, paro.lastDay)), findsOneWidget);
      expect(find.text('Taking bookings'), findsOneWidget); // Paro
    });

    testWidgets('payments are one month at a time: with more than a week left, the next one waits', (tester) async {
      final s = subscriptionFor(daysLeft: 21);
      final fakes = await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s);
      await openChangliSubscription(tester);

      expect(isEnabled(tester, AppStrings.recordPayment), isFalse);
      expect(find.text(AppStrings.nextPaymentFrom(s.lastDay, s.payableFrom)), findsOneWidget);
      // And the database refuses it anyway.
      await expectLater(
        fakes.subscriptions.recordPayment('venue-1', amountNu: 1500, method: BillingMethod.cash),
        throwsA(isA<Object>().having((e) => e.toString(), 'error', contains('KH409'))),
      );
      expect(fakes.subscriptions.periods, isEmpty);
    });

    testWidgets("an admin records the next month's payment in the last week: exactly one month", (tester) async {
      final s = subscriptionFor(daysLeft: 3);
      final fakes = await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s);
      await openChangliSubscription(tester);
      expect(isEnabled(tester, AppStrings.recordPayment), isTrue);

      await tapAndSettle(tester, AppStrings.recordPayment);
      final month = s.next(months: 1);
      final lastDay = VenueSubscription.lastDayBefore(month.end);
      expect(find.text(AppStrings.coversMonth(VenueSubscription.lastDayBefore(s.endsAt).add(const Duration(days: 1)), lastDay)),
          findsOneWidget);
      expect(find.text('1500'), findsOneWidget); // the ground's fee, to start with

      await enterField(tester, AppStrings.amountPaid, '');
      await tapButton(tester, AppStrings.savePayment);
      expect(find.text(AppStrings.enterAmount), findsOneWidget);
      expect(fakes.subscriptions.periods, isEmpty);

      await enterField(tester, AppStrings.amountPaid, '1500');
      await tapAndSettle(tester, AppStrings.billingMethodLabel(BillingMethod.mpay));
      await enterField(tester, AppStrings.journalNumberOptional, '123456');
      await tapButton(tester, AppStrings.savePayment);

      final paid = fakes.subscriptions.periods.single;
      expect(
        (paid.kind, paid.amountNu, paid.paymentMethod, paid.paymentReference, paid.startsAt, paid.endsAt),
        (SubscriptionKind.paid, 1500, BillingMethod.mpay, '123456', s.endsAt, month.end),
      );
      expect(find.text(AppStrings.paymentRecorded), findsOneWidget);
      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.paid, lastDay)), findsOneWidget);
      // Paid more than a week ahead now: the month after waits for its last week.
      expect(isEnabled(tester, AppStrings.recordPayment), isFalse);
      await tester.dragUntilVisible(find.text('${AppStrings.subscriptionKindLabel(SubscriptionKind.paid)} · '
          '${PriceUtils.nu(1500)}'), find.byType(Scrollable).first, const Offset(0, -250));
    });

    testWidgets('an admin gives free time, longer than a month', (tester) async {
      final s = subscriptionFor(daysLeft: 21);
      final fakes = await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s);
      await openChangliSubscription(tester);

      await tapAndSettle(tester, AppStrings.giveFreeTime);
      await tapAndSettle(tester, AppStrings.freeLength(3, 0));
      final end = VenueSubscription.periodEnd(s.endsAt, months: 3);
      expect(find.text(AppStrings.freeUntil(VenueSubscription.lastDayBefore(end))), findsOneWidget);
      await tapButton(tester, AppStrings.giveLengthFree(3, 0));

      final free = fakes.subscriptions.periods.single;
      expect((free.kind, free.startsAt, free.endsAt, free.amountNu), (SubscriptionKind.free, s.endsAt, end, null));
      expect(find.text(AppStrings.freeTimeGiven), findsOneWidget);
      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.free, VenueSubscription.lastDayBefore(end))),
          findsOneWidget);
    });

    testWidgets("an admin changes a ground's monthly fee", (tester) async {
      final fakes = await openGrounds(tester, role: UserRole.admin, manager: 'tashi');
      await openChangliSubscription(tester);

      await tapAndSettle(tester, AppStrings.changeFee);
      await enterField(tester, AppStrings.monthlyFee, '2000');
      await tapButton(tester, AppStrings.save);

      expect(fakes.venues.venues.first.subscription!.feeNu, 2000);
      expect(find.text(AppStrings.feeSaved), findsOneWidget);
      expect(feeRow(2000), findsOneWidget);
    });

    testWidgets('Billing settings: the fee for new grounds, and how managers pay', (tester) async {
      final fakes = await openGrounds(tester, role: UserRole.admin, manager: 'tashi');
      await openSettingsItem(tester, AppStrings.sportsVenues);
      await tester.tap(find.byTooltip(AppStrings.billingSettings));
      await tester.pumpAndSettle();

      await enterField(tester, AppStrings.defaultFee, '1800');
      await enterField(tester, AppStrings.howManagersPay, '  mPay 17123456 (Kuzu Help)  ');
      await tapButton(tester, AppStrings.save);

      final settings = fakes.subscriptions.settings;
      expect((settings.defaultFeeNu, settings.paymentInfo), (1800, 'mPay 17123456 (Kuzu Help)'));
      expect(find.text(AppStrings.billingSettingsSaved), findsOneWidget);
    });
  });

  group('notifications', () {
    final ends = DateTime.utc(2026, 11, 2, 18).toIso8601String(); // the midnight after Mon 2 Nov, Bhutan

    testWidgets("a reminder opens the ground's Subscription page", (tester) async {
      await openGrounds(tester, notices: [
        {
          'type': NotificationTypes.subscriptionEnding,
          'venue_id': 'venue-1',
          'venue_name': 'Changli Futsal',
          'kind': SubscriptionKind.trial,
          'ends_at': ends,
          'fee_nu': 1500,
        },
      ]);
      await tester.tap(find.byTooltip(AppStrings.notifications));
      await tester.pumpAndSettle();
      expect(find.text('Last day: Mon 2 Nov. ${AppStrings.payNextMonth(1500)}'), findsOneWidget);

      await tapAndSettle(tester, "Changli Futsal's free trial ends soon");
      expect(find.widgetWithText(AppBar, AppStrings.subscription), findsOneWidget);
      expect(feeRow(1500), findsOneWidget);
    });

    test('say what happened, until when, and what to pay', () {
      String title(String type, Map<String, dynamic> data) => AppStrings.notificationTitle(type, data);
      String body(String type, Map<String, dynamic> data) => AppStrings.notificationBody(type, data);
      final trial = {'venue_name': 'Changli Futsal', 'kind': 'trial', 'ends_at': ends, 'fee_nu': 1500};

      expect(title(NotificationTypes.subscriptionUpdated, trial), 'Free trial for Changli Futsal');
      expect(body(NotificationTypes.subscriptionUpdated, trial),
          'Listed for free until Mon 2 Nov. After that, Nu. 1,500 a month keeps it listed for players.');
      final paid = {'venue_name': 'Changli Futsal', 'kind': 'paid', 'ends_at': ends, 'amount_nu': 1500};
      expect(title(NotificationTypes.subscriptionUpdated, paid), 'Payment received for Changli Futsal');
      expect(body(NotificationTypes.subscriptionUpdated, paid), 'Nu. 1,500 · Paid until Mon 2 Nov.');
      expect(title(NotificationTypes.subscriptionUpdated, {...trial, 'kind': 'free'}), 'More free time for Changli Futsal');

      expect(title(NotificationTypes.subscriptionEnding, {...trial, 'kind': 'paid'}),
          "Changli Futsal's subscription ends soon");
      expect(title(NotificationTypes.subscriptionEnded, trial), 'Changli Futsal is hidden from players');
      expect(body(NotificationTypes.subscriptionEnded, trial),
          'Its free trial ended on Mon 2 Nov. Pay Nu. 1,500 for the next month to list it again.');
      expect(title(NotificationTypes.subscriptionLapsed, trial), "Changli Futsal's subscription ended");
      // Without the details: still makes sense.
      expect(title(NotificationTypes.subscriptionEnding, {}), "Your ground's free trial ends soon");
      expect(body(NotificationTypes.subscriptionEnding, {}), AppStrings.payNextMonth(null));
    });
  });
}
