final class TrainingInfo {
  const TrainingInfo({
    required this.title,
    required this.startsAt,
    required this.location,
    this.coach,
    this.notes,
  });

  final String title;
  final DateTime startsAt;
  final String location;
  final String? coach;
  final String? notes;
}
