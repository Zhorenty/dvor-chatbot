import 'package:dvor_chatbot/src/domain/activity_category.dart';

final class TrainingInfo {
  const TrainingInfo({
    required this.title,
    required this.startsAt,
    required this.location,
    this.endsAt,
    this.locationUrl,
    this.category = ActivityCategory.trainings,
    this.price,
    this.prepayPercent,
    this.participantsLimit,
    this.includeTrainersInParticipants = false,
    this.coach,
    this.notes,
    this.promoRestricted = false,
  });

  final String title;
  final DateTime startsAt;

  /// End of multi-day outdoor events; null for single-day trainings.
  final DateTime? endsAt;
  final String location;
  final String? locationUrl;
  final ActivityCategory category;
  final int? price;

  /// Outdoor prepayment share (1–100). Null for regular trainings.
  final int? prepayPercent;
  final int? participantsLimit;
  final bool includeTrainersInParticipants;
  final String? coach;
  final String? notes;

  /// When true, promo codes and free-training bonuses cannot be applied
  /// to bookings for this training.
  final bool promoRestricted;

  String get sessionKey =>
      '${category.name}|${startsAt.toUtc().toIso8601String()}|$title|$location';
}
