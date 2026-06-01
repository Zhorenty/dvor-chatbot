import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

final class ActivityCatalogService {
  const ActivityCatalogService({
    required TrainingScheduleRepository scheduleRepository,
  }) : _scheduleRepository = scheduleRepository;

  final TrainingScheduleRepository _scheduleRepository;

  ActivityCategory? parseCategory(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('трениров')) {
      return ActivityCategory.trainings;
    }
    if (normalized.contains('поход')) {
      return ActivityCategory.hikes;
    }
    if (normalized.contains('трейл')) {
      return ActivityCategory.trails;
    }
    return null;
  }

  List<TrainingInfo> bookableItems(ActivityCategory category, {int limit = 8}) {
    return switch (category) {
      ActivityCategory.trainings => _scheduleRepository.upcoming(limit: limit),
      ActivityCategory.hikes => _scheduleRepository
          .upcomingOutdoorActivities(limit: 20)
          .where((item) => item.type == OutdoorActivityType.hike)
          .take(limit)
          .map((item) => toBookableInfo(item))
          .toList(growable: false),
      ActivityCategory.trails => _scheduleRepository
          .upcomingOutdoorActivities(limit: 20)
          .where((item) => item.type == OutdoorActivityType.trail)
          .take(limit)
          .map((item) => toBookableInfo(item))
          .toList(growable: false),
    };
  }

  List<TrainingInfo> participantItems(ActivityCategory category, {int limit = 12}) {
    return switch (category) {
      ActivityCategory.trainings => _scheduleRepository.upcoming(limit: limit),
      ActivityCategory.hikes => _scheduleRepository
          .upcomingOutdoorActivities(limit: 24)
          .where((item) => item.type == OutdoorActivityType.hike)
          .take(limit)
          .map((item) => toBookableInfo(item))
          .toList(growable: false),
      ActivityCategory.trails => _scheduleRepository
          .upcomingOutdoorActivities(limit: 24)
          .where((item) => item.type == OutdoorActivityType.trail)
          .take(limit)
          .map((item) => toBookableInfo(item))
          .toList(growable: false),
    };
  }

  List<OutdoorActivityInfo> outdoorItems(ActivityCategory category) {
    return _scheduleRepository.upcomingOutdoorActivities().where((item) {
      return switch (category) {
        ActivityCategory.trainings => false,
        ActivityCategory.hikes => item.type == OutdoorActivityType.hike,
        ActivityCategory.trails => item.type == OutdoorActivityType.trail,
      };
    }).toList(growable: false);
  }

  ActivityCategory categoryForBooking(TrainingBooking booking) {
    final keyPrefix = booking.trainingKey.split('|').firstOrNull;
    if (keyPrefix != null) {
      for (final category in ActivityCategory.values) {
        if (category.name == keyPrefix) {
          return category;
        }
      }
    }

    // Backward-compatible fallback for older rows that were created before
    // category was embedded into the session key.
    final title = booking.trainingTitle;
    if (title.startsWith('🥾 Поход:')) {
      return ActivityCategory.hikes;
    }
    if (title.startsWith('🏃 Трейл:')) {
      return ActivityCategory.trails;
    }
    return ActivityCategory.trainings;
  }

  TrainingInfo toBookableInfo(OutdoorActivityInfo item) {
    final category =
        item.type == OutdoorActivityType.hike ? ActivityCategory.hikes : ActivityCategory.trails;
    final prefix = item.type == OutdoorActivityType.hike ? '🥾 Поход' : '🏃 Трейл';
    return TrainingInfo(
      title: '$prefix: ${item.title}',
      startsAt: item.dateFrom,
      location: item.description,
      category: category,
      price: item.price,
      notes: 'Даты: ${dateRangeLabel(item)}',
    );
  }

  String dateRangeLabel(OutdoorActivityInfo item) {
    final from = item.dateFrom;
    final to = item.dateTo;
    final sameDay = from.year == to.year && from.month == to.month && from.day == to.day;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final fromLabel = '${twoDigits(from.day)}.${twoDigits(from.month)}.${from.year}';
    if (sameDay) {
      return fromLabel;
    }
    final toLabel = '${twoDigits(to.day)}.${twoDigits(to.month)}.${to.year}';
    return '$fromLabel — $toLabel';
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
