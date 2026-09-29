import '../../core/constants/app_constants.dart';

/// Maps the job_requests table (supabase/updates.sql, section 11), with the
/// service's name and icon.
class JobRequest {
  final String id;
  final String customerId;
  final String workerId;
  final String customerName;
  final String workerName;
  final String? categoryName;
  final String? categoryIcon;
  final String description;
  final String? whenNeeded;
  final String address;
  final String contactPhone; // +975XXXXXXXX
  final String? photoPath; // in the private job-photos bucket
  final String status; // a JobStatus value
  final String? workerNote;
  final DateTime createdAt;

  const JobRequest({
    required this.id,
    required this.customerId,
    required this.workerId,
    this.customerName = '',
    this.workerName = '',
    this.categoryName,
    this.categoryIcon,
    required this.description,
    this.whenNeeded,
    required this.address,
    required this.contactPhone,
    this.photoPath,
    required this.status,
    this.workerNote,
    required this.createdAt,
  });

  bool get isOpen => JobStatus.isOpen(status);

  /// job_requests columns plus the service's name and icon.
  static const columns = '*, service_categories(name, icon)';

  factory JobRequest.fromJson(Map<String, dynamic> json) {
    final category = json['service_categories'] as Map<String, dynamic>?;
    return JobRequest(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      workerId: json['worker_id'] as String,
      customerName: json['customer_name'] as String? ?? '',
      workerName: json['worker_name'] as String? ?? '',
      categoryName: category?['name'] as String?,
      categoryIcon: category?['icon'] as String?,
      description: json['description'] as String,
      whenNeeded: json['when_needed'] as String?,
      address: json['address'] as String,
      contactPhone: json['contact_phone'] as String,
      photoPath: json['photo_path'] as String?,
      status: json['status'] as String,
      workerNote: json['worker_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  JobRequest withStatus(String newStatus, {String? note}) => JobRequest(
        id: id,
        customerId: customerId,
        workerId: workerId,
        customerName: customerName,
        workerName: workerName,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        description: description,
        whenNeeded: whenNeeded,
        address: address,
        contactPhone: contactPhone,
        photoPath: photoPath,
        status: newStatus,
        workerNote: note ?? workerNote,
        createdAt: createdAt,
      );
}
