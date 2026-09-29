/// Maps the reviews table. Reviewers' names aren't shown: the profiles rules
/// only let users read their own row.
class Review {
  final String id;
  final String workerId;
  final String customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.workerId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        customerId: json['customer_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
