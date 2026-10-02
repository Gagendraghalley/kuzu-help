import '../../core/constants/app_constants.dart';
import '../../core/utils/geo_utils.dart';
import 'subscription.dart';

/// A venue: one row of the venue_directory view (listed venues, what
/// customers see), or, for its manager and admins, of the venues table with
/// the manager's name and contacts (supabase/updates.sql, section 13).
class Venue {
  final String id;
  final String? managerId; // null: no manager yet, so customers can't book it
  final String venueType; // a VenueType value
  final String name;
  final String? description;
  final String dzongkhag;
  final String? town;
  final String? address;
  final String phone; // +975XXXXXXXX
  final String? whatsappNumber;
  final String? coverUrl; // public venue-photos bucket
  final bool autoConfirm; // bookings are confirmed without the manager
  final int freeCancelHours;
  final String? cancellationPolicy;
  final String? paymentInfo; // how to pay an advance, e.g. an mBoB account
  final GeoPoint? coordinates; // its place on the map; null until its manager sets it
  // venue_directory only:
  final int? fromPriceNu; // the cheapest ground's hourly price
  final int groundCount;
  final List<String> sports; // Sport values
  final double avgRating;
  final int reviewCount;
  // The venues table only (the manager and admins):
  final String? managerName;
  final String? managerEmail;
  final String? managerPhone;
  final bool managerActive; // false once an admin deactivates the manager
  final bool isActive; // false: bookings are paused
  // Null in venue_directory rows: those are all subscribed.
  final VenueSubscription? subscription;

  const Venue({
    required this.id,
    this.managerId,
    this.venueType = VenueType.sportsGround,
    required this.name,
    this.description,
    required this.dzongkhag,
    this.town,
    this.address,
    required this.phone,
    this.whatsappNumber,
    this.coverUrl,
    this.autoConfirm = false,
    this.freeCancelHours = 24,
    this.cancellationPolicy,
    this.paymentInfo,
    this.coordinates,
    this.fromPriceNu,
    this.groundCount = 0,
    this.sports = const [],
    this.avgRating = 0,
    this.reviewCount = 0,
    this.managerName,
    this.managerEmail,
    this.managerPhone,
    this.managerActive = true,
    this.isActive = true,
    this.subscription,
  });

  /// venues columns plus the manager's name, contacts and whether they are
  /// active. Their profile is named (!venues_manager_id_fkey): other tables
  /// link profiles to venues too.
  static const columns = '*, manager:profiles!venues_manager_id_fkey(full_name, email, phone, is_active)';

  /// A venue_directory row (listed), or a venues row selected with [columns].
  factory Venue.fromJson(Map<String, dynamic> json) {
    final manager = json['manager'] as Map<String, dynamic>?;
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    return Venue(
      id: json['id'] as String,
      managerId: json['manager_id'] as String?,
      venueType: json['venue_type'] as String? ?? VenueType.sportsGround,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      dzongkhag: json['dzongkhag'] as String? ?? '',
      town: json['town'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      coverUrl: json['cover_url'] as String?,
      autoConfirm: json['auto_confirm'] as bool? ?? false,
      freeCancelHours: json['free_cancel_hours'] as int? ?? 24,
      cancellationPolicy: json['cancellation_policy'] as String?,
      paymentInfo: json['payment_info'] as String?,
      coordinates: latitude == null || longitude == null ? null : GeoPoint(latitude, longitude),
      fromPriceNu: json['from_price_nu'] as int?,
      groundCount: json['ground_count'] as int? ?? 0,
      sports: (json['sports'] as List?)?.cast<String>() ?? const [],
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      managerName: manager?['full_name'] as String?,
      managerEmail: manager?['email'] as String?,
      managerPhone: manager?['phone'] as String?,
      managerActive: manager?['is_active'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      subscription: switch (json['subscription_ends_at']) {
        final String endsAt => VenueSubscription(
            endsAt: DateTime.parse(endsAt),
            kind: json['subscription_kind'] as String? ?? SubscriptionKind.trial,
            feeNu: json['subscription_fee_nu'] as int?,
          ),
        _ => null,
      },
    );
  }

  bool get hasManager => managerId != null;

  /// Its subscription has ended, so players can't find or book it.
  bool get subscriptionEnded => subscription?.isEnded() ?? false;

  /// Customers can find and book it (the database also checks that a ground
  /// is taking bookings).
  bool get isListed => hasManager && managerActive && isActive && !subscriptionEnded;

  /// 'Town, Dzongkhag', or whichever of the two is known.
  String get location =>
      [town, dzongkhag].where((part) => part != null && part.trim().isNotEmpty).join(', ');
}

/// What an admin fills in when adding a venue, or its manager when editing it.
class VenueDraft {
  final String name;
  final String dzongkhag;
  final String? town;
  final String? address;
  final String phone;
  final String? whatsappNumber;
  final String? description;
  final bool autoConfirm;
  final int freeCancelHours;
  final String? cancellationPolicy;
  final String? paymentInfo;
  final GeoPoint? coordinates; // null: not on the map (or no longer)

  const VenueDraft({
    required this.name,
    required this.dzongkhag,
    this.town,
    this.address,
    required this.phone,
    this.whatsappNumber,
    this.description,
    this.autoConfirm = false,
    this.freeCancelHours = 24,
    this.cancellationPolicy,
    this.paymentInfo,
    this.coordinates,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'dzongkhag': dzongkhag,
        'town': town,
        'address': address,
        'phone': phone,
        'whatsapp_number': whatsappNumber,
        'description': description,
        'auto_confirm': autoConfirm,
        'free_cancel_hours': freeCancelHours,
        'cancellation_policy': cancellationPolicy,
        'payment_info': paymentInfo,
        'latitude': coordinates?.latitude,
        'longitude': coordinates?.longitude,
      };
}
