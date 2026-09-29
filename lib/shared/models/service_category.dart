/// Maps the service_categories table.
class ServiceCategory {
  final String id;
  final String name;
  final String? nameDz;
  final String? icon;
  final bool isActive;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.nameDz,
    this.icon,
    required this.isActive,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        nameDz: json['name_dz'] as String?,
        icon: json['icon'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
