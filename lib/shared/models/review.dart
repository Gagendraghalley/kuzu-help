/// Maps the reviews table. Reviewers' names aren't shown: the profiles rules
/// only let users read their own row. [reply] is the worker's public answer
/// (supabase/updates.sql, section 8).
class Review {
  final String id;
  final String workerId;
  final String customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? reply;
  final DateTime? repliedAt;

  const Review({
    required this.id,
    required this.workerId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        customerId: json['customer_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        reply: json['reply'] as String?,
        repliedAt: json['replied_at'] == null ? null : DateTime.parse(json['replied_at'] as String),
      );
}
