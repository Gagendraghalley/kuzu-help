/// Maps the work_photos table (supabase/updates.sql, section 9): a photo of a
/// worker's past work. [url] is the file's public link.
class WorkPhoto {
  final String id;
  final String workerId;
  final String path; // in the work-photos bucket
  final String url;

  const WorkPhoto({required this.id, required this.workerId, required this.path, required this.url});

  factory WorkPhoto.fromJson(Map<String, dynamic> json, {required String url}) => WorkPhoto(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        path: json['path'] as String,
        url: url,
      );
}
