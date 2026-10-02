class TrainingLocation {
  const TrainingLocation({
    required this.id,
    required this.name,
    required this.slug,
    required this.locationType,
    required this.isPartner,
    this.area,
  });

  final String id;
  final String name;
  final String slug;
  final String locationType;
  final String? area;
  final bool isPartner;

  factory TrainingLocation.fromJson(Map<String, dynamic> json) {
    return TrainingLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      locationType: json['location_type'] as String,
      area: json['area'] as String?,
      isPartner: json['is_partner'] as bool? ?? false,
    );
  }
}
