class TrainerSpecialty {
  const TrainerSpecialty({
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

  factory TrainerSpecialty.fromJson(Map<String, dynamic> json) {
    return TrainerSpecialty(
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}