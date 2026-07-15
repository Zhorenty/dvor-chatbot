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
    if (normalized.contains('йог')) {
      return ActivityCategory.yoga;
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
      ActivityCategory.yoga => _scheduleRepository.upcomingYoga(limit: limit),
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
      ActivityCategory.yoga => _scheduleRepository.upcomingYoga(limit: limit),
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
        ActivityCategory.yoga => false,
        ActivityCategory.hikes => item.type == OutdoorActivityType.hike,
        ActivityCategory.trails => item.type == OutdoorActivityType.trail,
      };
    }).toList(growable: false);
  }

  OutdoorActivityInfo? outdoorByBooking(TrainingBooking booking) {
    final category = categoryForBooking(booking);
    if (category != ActivityCategory.hikes && category != ActivityCategory.trails) {
      return null;
    }
    final items = outdoorItems(category);
    if (items.isEmpty) {
      return null;
    }
    final normalizedBookingTitle = _normalizeOutdoorTitle(booking.trainingTitle);
    final exactByTitle = items.where(
      (item) => _normalizeOutdoorTitle(item.title) == normalizedBookingTitle,
    );
    final exactByDate = exactByTitle.where((item) => _isSameDay(item.dateFrom, booking.startsAt));
    if (exactByDate.isNotEmpty) {
      return exactByDate.first;
    }
    if (exactByTitle.isNotEmpty) {
      return exactByTitle.first;
    }
    return null;
  }

  /// Returns the [TrainingInfo] from the current schedule that matches [booking],
  /// or null if the training is no longer in the schedule cache.
  TrainingInfo? trainingInfoForBooking(TrainingBooking booking) {
    final category = categoryForBooking(booking);
    final items = bookableItems(category, limit: 20);
    for (final item in items) {
      if (item.sessionKey == booking.trainingKey) {
        return item;
      }
    }
    return null;
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
    if (title.startsWith('🧘 Йога:')) {
      return ActivityCategory.yoga;
    }
    return ActivityCategory.trainings;
  }

  TrainingInfo toBookableInfo(OutdoorActivityInfo item) {
    final category =
        item.type == OutdoorActivityType.hike ? ActivityCategory.hikes : ActivityCategory.trails;
    final prefix = item.type == OutdoorActivityType.hike ? '🥾 Поход' : '🏃 Трейл';
    final location = item.location?.trim();
    return TrainingInfo(
      title: '$prefix: ${item.title}',
      startsAt: item.dateFrom,
      location: (location == null || location.isEmpty) ? item.description : location,
      category: category,
      price: item.price,
      participantsLimit: item.participantsLimit,
      includeTrainersInParticipants: true,
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

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  String _normalizeOutdoorTitle(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceFirst(RegExp(r'^🥾\s*поход:\s*'), '');
    normalized = normalized.replaceFirst(RegExp(r'^🏃\s*трейл:\s*'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
