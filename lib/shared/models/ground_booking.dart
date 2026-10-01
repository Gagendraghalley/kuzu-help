import '../../core/constants/app_constants.dart';
import '../../core/utils/bhutan_time.dart';
import 'ground.dart';

/// One row of the ground_booking_list view: a booking (or the manager's
/// blocked time) with its ground and venue (supabase/updates.sql, section 13).
class GroundBooking {
  final String id;
  final String groundId;
  final String bookedBy; // the customer; for a block, whoever blocked it
  final String kind; // a BookingKind value
  final DateTime startsAt;
  final DateTime endsAt;
  final String status; // a BookingStatus value
  final int priceNu;
  final String? teamName;
  final int? playersCount;
  final String contactName;
  final String? contactPhone; // +975XXXXXXXX
  final String paymentMethod; // a PaymentMethod value
  final String? paymentReference; // mBoB / mPay journal number
  final String paymentStatus; // a PaymentStatus value
  final String? customerNote;
  final String? ownerNote; // the venue's message, or why the time is blocked
  final String? cancelledBy; // null when cancelled: it expired unanswered
  final DateTime createdAt;
  final String groundName;
  final String sport;
  final String venueId;
  final String? managerId; // who runs the venue; null: nobody at the moment
  final String venueName;
  final String? venueTown;
  final String venueDzongkhag;
  final String venuePhone;
  final String? venueWhatsapp;
  final int freeCancelHours;
  final String? paymentInfo;

  const GroundBooking({
    required this.id,
    required this.groundId,
    required this.bookedBy,
    this.kind = BookingKind.customer,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.priceNu = 0,
    this.teamName,
    this.playersCount,
    this.contactName = '',
    this.contactPhone,
    this.paymentMethod = PaymentMethod.payAtVenue,
    this.paymentReference,
    this.paymentStatus = PaymentStatus.unpaid,
    this.customerNote,
    this.ownerNote,
    this.cancelledBy,
    required this.createdAt,
    required this.groundName,
    this.sport = Sport.futsal,
    required this.venueId,
    this.managerId,
    required this.venueName,
    this.venueTown,
    this.venueDzongkhag = '',
    this.venuePhone = '',
    this.venueWhatsapp,
    this.freeCancelHours = 24,
    this.paymentInfo,
  });

  factory GroundBooking.fromJson(Map<String, dynamic> json) => GroundBooking(
        id: json['id'] as String,
        groundId: json['ground_id'] as String,
        bookedBy: json['booked_by'] as String,
        kind: json['kind'] as String? ?? BookingKind.customer,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        status: json['status'] as String,
        priceNu: json['price_nu'] as int? ?? 0,
        teamName: json['team_name'] as String?,
        playersCount: json['players_count'] as int?,
        contactName: json['contact_name'] as String? ?? '',
        contactPhone: json['contact_phone'] as String?,
        paymentMethod: json['payment_method'] as String? ?? PaymentMethod.payAtVenue,
        paymentReference: json['payment_reference'] as String?,
        paymentStatus: json['payment_status'] as String? ?? PaymentStatus.unpaid,
        customerNote: json['customer_note'] as String?,
        ownerNote: json['owner_note'] as String?,
        cancelledBy: json['cancelled_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        groundName: json['ground_name'] as String? ?? '',
        sport: json['sport'] as String? ?? Sport.futsal,
        venueId: json['venue_id'] as String,
        managerId: json['manager_id'] as String?,
        venueName: json['venue_name'] as String? ?? '',
        venueTown: json['venue_town'] as String?,
        venueDzongkhag: json['venue_dzongkhag'] as String? ?? '',
        venuePhone: json['venue_phone'] as String? ?? '',
        venueWhatsapp: json['venue_whatsapp'] as String?,
        freeCancelHours: json['free_cancel_hours'] as int? ?? 24,
        paymentInfo: json['payment_info'] as String?,
      );

  bool get isBlock => kind == BookingKind.ownerBlock;

  /// The manager booked it for someone who called; they aren't told in the app.
  bool get isPhone => kind == BookingKind.phone;

  /// Still holding its time: waiting for the manager, or confirmed.
  bool get isOpen => BookingStatus.isOpen(status);

  int get hours => endsAt.difference(startsAt).inHours;

  bool hasStarted([DateTime? now]) => !startsAt.isAfter(now ?? DateTime.now());

  bool hasEnded([DateTime? now]) => !endsAt.isAfter(now ?? DateTime.now());

  /// Still to come or going on: shown under 'Upcoming'.
  bool isUpcoming([DateTime? now]) => isOpen && !hasEnded(now);

  /// Cancelling now is after the venue's free cancellation time.
  bool isLateToCancel([DateTime? now]) =>
      startsAt.subtract(Duration(hours: freeCancelHours)).isBefore(now ?? DateTime.now());

  /// The customer played, so may review the venue (has_played_at).
  bool get canBeReviewed =>
      kind == BookingKind.customer &&
      (status == BookingStatus.confirmed || status == BookingStatus.completed) &&
      hasEnded();

  /// Its day of the week and hours in Bhutan: what a regular booking made
  /// from it holds every week.
  TimeSlot get weeklyTime {
    final start = BhutanTime.of(startsAt);
    return TimeSlot(weekday: start.weekday % 7, startHour: start.hour, endHour: start.hour + hours);
  }

  /// The manager may make it regular (make_booking_regular): someone's
  /// booking, confirmed or played.
  bool get canBeMadeRegular =>
      !isBlock && (status == BookingStatus.confirmed || status == BookingStatus.completed);

  bool get paidAdvanceByTransfer => paymentMethod != PaymentMethod.payAtVenue;

  /// 'Town, Dzongkhag' of the venue, or whichever of the two is known.
  String get venueLocation =>
      [venueTown, venueDzongkhag].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  GroundBooking copyWith({
    String? status,
    String? ownerNote,
    String? paymentStatus,
    String? paymentReference,
    String? cancelledBy,
  }) =>
      GroundBooking(
        id: id,
        groundId: groundId,
        bookedBy: bookedBy,
        kind: kind,
        startsAt: startsAt,
        endsAt: endsAt,
        status: status ?? this.status,
        priceNu: priceNu,
        teamName: teamName,
        playersCount: playersCount,
        contactName: contactName,
        contactPhone: contactPhone,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        customerNote: customerNote,
        ownerNote: ownerNote ?? this.ownerNote,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        createdAt: createdAt,
        groundName: groundName,
        sport: sport,
        venueId: venueId,
        managerId: managerId,
        venueName: venueName,
        venueTown: venueTown,
        venueDzongkhag: venueDzongkhag,
        venuePhone: venuePhone,
        venueWhatsapp: venueWhatsapp,
        freeCancelHours: freeCancelHours,
        paymentInfo: paymentInfo,
      );
}

/// A time on a ground that's taken, from get_ground_availability: no names,
/// only when, whether the manager blocked it, whether it's a confirmed
/// booking (false: a request waiting for the manager's answer), and whether
/// it's a regular booking (every week).
typedef BusyTime = ({DateTime start, DateTime end, bool blocked, bool confirmed, bool regular});
