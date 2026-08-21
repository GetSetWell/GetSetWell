class TrainerFitPoint {
  const TrainerFitPoint({
    required this.id,
    required this.text,
    required this.displayOrder,
  });

  final String id;
  final String text;
  final int displayOrder;

  factory TrainerFitPoint.fromJson(Map<String, dynamic> json) {
    return TrainerFitPoint(
      id: json['id'] as String,
      text: json['text'] as String,
      displayOrder: json['display_order'] as int? ?? 999,
    );
  }
}