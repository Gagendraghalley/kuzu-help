/// Maps the worker_services table, with the category's name and icon when
/// selected as `service_categories(name, icon)`.
class WorkerService {
  final String workerId;
  final String categoryId;
  final String? priceNote;
  final String? categoryName;
  final String? categoryIcon;

  const WorkerService({
    required this.workerId,
    required this.categoryId,
    this.priceNote,
    this.categoryName,
    this.categoryIcon,
  });

  factory WorkerService.fromJson(Map<String, dynamic> json) {
    final category = json['service_categories'] as Map<String, dynamic>?;
    return WorkerService(
      workerId: json['worker_id'] as String,
      categoryId: json['category_id'] as String,
      priceNote: json['price_note'] as String?,
      categoryName: category?['name'] as String?,
      categoryIcon: category?['icon'] as String?,
    );
  }
}
