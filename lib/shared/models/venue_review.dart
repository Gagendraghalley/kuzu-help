/// Maps the venue_reviews table (supabase/updates.sql, section 13). Like
/// workers' reviews, they don't show the customer's name.
class VenueReview {
  final String id;
  final String venueId;
  final String customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const VenueReview({
    required this.id,
    required this.venueId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory VenueReview.fromJson(Map<String, dynamic> json) => VenueReview(
        id: json['id'] as String,
        venueId: json['venue_id'] as String,
        customerId: json['customer_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
