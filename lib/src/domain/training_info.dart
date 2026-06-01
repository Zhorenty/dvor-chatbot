import 'package:dvor_chatbot/src/domain/activity_category.dart';

final class TrainingInfo {
  const TrainingInfo({
    required this.title,
    required this.startsAt,
    required this.location,
    this.category = ActivityCategory.trainings,
    this.price,
    this.coach,
    this.notes,
  });

  final String title;
  final DateTime startsAt;
  final String location;
  final ActivityCategory category;
  final int? price;
  final String? coach;
  final String? notes;

  String get sessionKey =>
      '${category.name}|${startsAt.toUtc().toIso8601String()}|$title|$location';
}
