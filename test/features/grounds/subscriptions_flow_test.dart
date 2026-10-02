import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/utils/bhutan_time.dart';
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
      for (final adminOnly in [
        AppStrings.recordPayment,
        AppStrings.giveFreeTime,
        AppStrings.shortenFreeTime,
        AppStrings.changeFee,
      ]) {
        expect(find.text(adminOnly), findsNothing, reason: adminOnly);
      }
      expect(find.byTooltip(AppStrings.emailInvoice), findsNothing);
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

    testWidgets('an admin takes back free time not had yet: 6 months given ends today instead', (tester) async {
      final s = subscriptionFor(daysLeft: 180, kind: SubscriptionKind.free);
      final given = SubscriptionPeriod(
        id: 'period-free',
        venueId: 'venue-1',
        kind: SubscriptionKind.free,
        startsAt: DateTime.now().subtract(const Duration(days: 2)),
        endsAt: s.endsAt,
        note: 'Opening offer',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final fakes =
          await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s, periods: [given]);
      await openChangliSubscription(tester);

      await tapAndSettle(tester, AppStrings.shortenFreeTime);
      expect(find.text(AppStrings.freeUntil(s.lastDay)), findsOneWidget);
      // Nothing happens until a day is chosen.
      expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, AppStrings.shortenFreeTime)).onPressed,
          isNull);

      await tapAndSettle(tester, AppStrings.chooseLastDay);
      await tapAndSettle(tester, 'OK'); // the earliest it can be: today
      final today = BhutanTime.today();
      expect(find.text(AppStrings.newLastDay(today)), findsOneWidget);
      expect(find.text(AppStrings.listedUntil(today)), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, AppStrings.billingNote), 'Agreed on one month');
      await tapButton(tester, AppStrings.shortenFreeTime);

      final end = BhutanTime.at(today.add(const Duration(days: 1)), 0);
      final shortened = fakes.subscriptions.periods.single;
      expect((shortened.kind, shortened.startsAt, shortened.endsAt, shortened.note),
          (SubscriptionKind.free, given.startsAt, end, 'Opening offer · Agreed on one month'));
      expect(find.text(AppStrings.freeTimeShortened), findsOneWidget);
      expect(find.text(AppStrings.listedUntil(today)), findsOneWidget);
      // Its last day: nothing after today is left to take back.
      expect(find.text(AppStrings.shortenFreeTime), findsNothing);
    });

    testWidgets('free time after a month paid for can all go, but the paid month stays', (tester) async {
      final s = subscriptionFor(daysLeft: 40, kind: SubscriptionKind.free);
      final paidEnd = BhutanTime.at(BhutanTime.today().add(const Duration(days: 11)), 0); // last day in 10 days
      final paid = SubscriptionPeriod(
        id: 'period-paid',
        venueId: 'venue-1',
        kind: SubscriptionKind.paid,
        startsAt: paidEnd.subtract(const Duration(days: 30)),
        endsAt: paidEnd,
        amountNu: 1500,
        paymentMethod: BillingMethod.mbob,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      );
      final free = SubscriptionPeriod(
        id: 'period-free',
        venueId: 'venue-1',
        kind: SubscriptionKind.free,
        startsAt: paidEnd,
        endsAt: s.endsAt,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final fakes = await openGrounds(tester,
          role: UserRole.admin, manager: 'tashi', subscription: s, periods: [free, paid]);
      await openChangliSubscription(tester);

      await tapAndSettle(tester, AppStrings.shortenFreeTime);
      await tapAndSettle(tester, AppStrings.chooseLastDay);
      await tapAndSettle(tester, 'OK'); // the earliest it can be: the last day paid for
      final paidLastDay = VenueSubscription.lastDayBefore(paidEnd);
      expect(find.text(AppStrings.newLastDay(paidLastDay)), findsOneWidget);
      await tapButton(tester, AppStrings.shortenFreeTime);

      expect(fakes.subscriptions.periods.map((p) => p.id), ['period-paid']);
      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.paid, paidLastDay)), findsOneWidget);
      expect(find.text(AppStrings.shortenFreeTime), findsNothing);
      // And the database keeps paid months anyway.
      await expectLater(
        fakes.subscriptions.shortenFreeTime('venue-1', lastDay: BhutanTime.today()),
        throwsA(isA<Object>().having((e) => e.toString(), 'error', contains('KH410'))),
      );
    });

    testWidgets("each payment has an invoice; an admin emails it to the manager again", (tester) async {
      final s = subscriptionFor(daysLeft: 21, kind: SubscriptionKind.paid);
      final paid = SubscriptionPeriod(
        id: 'period-paid',
        venueId: 'venue-1',
        kind: SubscriptionKind.paid,
        startsAt: s.endsAt.subtract(const Duration(days: 30)),
        endsAt: s.endsAt,
        amountNu: 1500,
        paymentMethod: BillingMethod.mbob,
        invoiceNumber: 'KH-2026-00001',
        invoiceSentAt: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      );
      final fakes =
          await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: s, periods: [paid]);
      await openChangliSubscription(tester);
      await scrollAndTap(tester, find.byTooltip(AppStrings.emailInvoice));
      expect(find.textContaining(AppStrings.invoiceLabel('KH-2026-00001', emailed: true)), findsOneWidget);
      await tester.pumpAndSettle();
      expect(fakes.subscriptions.emailedInvoices, ['period-paid']);
      expect(find.text(AppStrings.invoiceEmailing), findsOneWidget);

      // Until emailing is set up, the admin is told what's missing.
      fakes.subscriptions.invoiceEmailsOn = false;
      ScaffoldMessenger.of(tester.element(find.byTooltip(AppStrings.emailInvoice))).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.emailInvoice));
      await tester.pumpAndSettle();
      expect(find.text("Invoice emails aren't set up yet: Vault has no kuzu_project_url secret."), findsOneWidget);
      expect(fakes.subscriptions.emailedInvoices, ['period-paid']);
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

  group('Billing (admins): every ground in one place', () {
    testWidgets('the soonest to end first, with what is due; filters show who to chase', (tester) async {
      await openGrounds(tester, role: UserRole.admin, manager: 'tashi', subscription: subscriptionFor(daysLeft: -2));
      await openSettingsItem(tester, AppStrings.billing);

      // Changli has ended, Paro is paid for 15 more days.
      expect(tester.getTopLeft(find.text('Changli Futsal')).dy, lessThan(tester.getTopLeft(find.text('Paro Arena')).dy));
      expect(find.text(AppStrings.subscriptionEnded), findsOneWidget);
      final paro = subscriptionFor(daysLeft: 15, kind: SubscriptionKind.paid);
      expect(find.text(AppStrings.subscriptionUntil(SubscriptionKind.paid, paro.lastDay)), findsOneWidget);
      expect(find.text(AppStrings.recordPayment), findsOneWidget); // only Changli's is due
      expect(find.text(AppStrings.billingHidden), findsOneWidget);
      for (final (label, count) in [
        (AppStrings.billingAll, 2),
        (AppStrings.billingToPay, 1),
        (AppStrings.billingFree, 0),
        (AppStrings.subscriptionKindLabel(SubscriptionKind.paid), 1),
      ]) {
        expect(find.text(AppStrings.withCount(label, count)), findsOneWidget, reason: label);
      }

      await tapAndSettle(tester, AppStrings.withCount(AppStrings.subscriptionKindLabel(SubscriptionKind.paid), 1));
      expect(find.text('Changli Futsal'), findsNothing);
      expect(find.text('Paro Arena'), findsOneWidget);
      await tapAndSettle(tester, AppStrings.withCount(AppStrings.billingFree, 0));
      expect(find.text(AppStrings.noGroundsHere), findsOneWidget);
      await tapAndSettle(tester, AppStrings.withCount(AppStrings.billingToPay, 1));
      expect(find.text('Changli Futsal'), findsOneWidget);
      expect(find.text('Paro Arena'), findsNothing);

      // A ground opens its Subscription page, for free time and its fee.
      await tapAndSettle(tester, 'Changli Futsal');
      expect(find.widgetWithText(AppBar, AppStrings.subscription), findsOneWidget);
      expect(find.text(AppStrings.giveFreeTime), findsOneWidget);
    });

    testWidgets('an admin records a payment straight from the list, and finds it in History', (tester) async {
      final s = subscriptionFor(daysLeft: -2);
      final fakes = await openGrounds(tester,
          role: UserRole.admin, manager: 'tashi', subscription: s, periods: [periodOf(s)]);
      await openSettingsItem(tester, AppStrings.billing);

      await tapAndSettle(tester, AppStrings.recordPayment);
      expect(find.text('1500'), findsOneWidget); // the ground's fee, to start with
      await tapButton(tester, AppStrings.savePayment);

      final paid = fakes.subscriptions.periods.first;
      expect((paid.venueId, paid.kind, paid.amountNu), ('venue-1', SubscriptionKind.paid, 1500));
      expect(find.text(AppStrings.paymentRecorded), findsOneWidget);
      expect(find.text(AppStrings.recordPayment), findsNothing); // paid a month ahead now
      expect(find.text(PriceUtils.nu(1500)), findsOneWidget); // received this month

      await tapAndSettle(tester, AppStrings.billingRecords);
      // Latest first: the payment, then Changli's free trial.
      final payment = find.textContaining('${AppStrings.subscriptionKindLabel(SubscriptionKind.paid)} · ${PriceUtils.nu(1500)}');
      final trial = find.textContaining(AppStrings.subscriptionKindLabel(SubscriptionKind.trial));
      expect(find.text('Changli Futsal'), findsNWidgets(2));
      expect(tester.getTopLeft(payment).dy, lessThan(tester.getTopLeft(trial).dy));

      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, AppStrings.subscription), findsOneWidget);
    });

    testWidgets('Billing settings are here too', (tester) async {
      await openGrounds(tester, role: UserRole.admin, manager: 'tashi');
      await openSettingsItem(tester, AppStrings.billing);
      await tester.tap(find.byTooltip(AppStrings.billingSettings));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.defaultFee), findsOneWidget);
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
      expect(body(NotificationTypes.subscriptionUpdated, {...paid, 'invoice_number': 'KH-2026-00001'}),
          'Nu. 1,500 · Paid until Mon 2 Nov. Invoice KH-2026-00001.');
      // Admins: another admin recorded a payment; a ground's payment is coming up.
      final recorded = {...paid, 'payment_method': BillingMethod.mbob, 'invoice_number': 'KH-2026-00001'};
      expect(title(NotificationTypes.subscriptionPaid, recorded), 'Payment recorded for Changli Futsal');
      expect(body(NotificationTypes.subscriptionPaid, recorded), 'Nu. 1,500 · mBoB transfer · Paid until Mon 2 Nov.');
      expect(title(NotificationTypes.subscriptionDue, trial), 'Payment due soon: Changli Futsal');
      expect(body(NotificationTypes.subscriptionDue, trial),
          "Last day: Mon 2 Nov. Record the next month's payment (Nu. 1,500) once they pay.");
      expect(body(NotificationTypes.subscriptionDue, {}), "Record the next month's payment once they pay.");
      expect(title(NotificationTypes.subscriptionUpdated, {...trial, 'kind': 'free'}), 'More free time for Changli Futsal');
      final shortened = {...trial, 'kind': 'free', 'note': 'Agreed on one month'};
      expect(title(NotificationTypes.subscriptionShortened, shortened), 'Less free time for Changli Futsal');
      expect(body(NotificationTypes.subscriptionShortened, shortened),
          'Listed until Mon 2 Nov. After that, Nu. 1,500 a month keeps it listed for players. Agreed on one month');

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
