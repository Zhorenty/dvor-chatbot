import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/boxing_title.dart';
import 'package:dvor_chatbot/src/domain/camp_title.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';

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
    if (normalized.contains('трейл') ||
        normalized.contains('кэмп') ||
        isCampActivityTitle(normalized)) {
      return ActivityCategory.trails;
    }
    return null;
  }

  List<TrainingInfo> bookableItems(ActivityCategory category, {int limit = 8}) {
    return switch (category) {
      ActivityCategory.trainings => _scheduleRepository
          .upcoming(limit: limit)
          .where((item) => !isCampActivityTitle(item.title))
          .toList(growable: false),
      ActivityCategory.hikes => _outdoorOf(category, fetchLimit: 20, limit: limit)
          .map(toBookableInfo)
          .toList(growable: false),
      ActivityCategory.trails => _outdoorOf(category, fetchLimit: 20, limit: limit)
          .map(toBookableInfo)
          .toList(growable: false),
    };
  }

  List<TrainingInfo> participantItems(ActivityCategory category, {int limit = 12}) {
    return switch (category) {
      ActivityCategory.trainings => _scheduleRepository
          .upcoming(limit: limit)
          .where((item) => !isCampActivityTitle(item.title))
          .toList(growable: false),
      ActivityCategory.hikes => _outdoorOf(category, fetchLimit: 24, limit: limit)
          .map(toBookableInfo)
          .toList(growable: false),
      ActivityCategory.trails => _outdoorOf(category, fetchLimit: 24, limit: limit)
          .map(toBookableInfo)
          .toList(growable: false),
    };
  }

  List<OutdoorActivityInfo> outdoorItems(ActivityCategory category) {
    return _outdoorOf(category, fetchLimit: 24, limit: 24);
  }

  List<OutdoorActivityInfo> _outdoorOf(
    ActivityCategory category, {
    required int fetchLimit,
    required int limit,
    DateTime? now,
  }) {
    final typed = _scheduleRepository.upcomingOutdoorActivities(now: now, limit: fetchLimit).where((
      item,
    ) {
      return switch (category) {
        ActivityCategory.trainings => false,
        ActivityCategory.hikes => item.type == OutdoorActivityType.hike,
        ActivityCategory.trails => item.type == OutdoorActivityType.trail,
      };
    }).take(limit);
    if (category != ActivityCategory.trails) {
      return typed.toList(growable: false);
    }
    return <OutdoorActivityInfo>[
      ...typed,
      ..._campsFromTrainings(now: now),
    ];
  }

  List<OutdoorActivityInfo> _campsFromTrainings({DateTime? now}) {
    return _scheduleRepository
        .upcoming(now: now, limit: 80)
        .where((item) => isCampActivityTitle(item.title))
        .map(_trainingToCamp)
        .toList(growable: false);
  }

  OutdoorActivityInfo _trainingToCamp(TrainingInfo item) {
    final notes = item.notes?.trim();
    return OutdoorActivityInfo(
      type: OutdoorActivityType.trail,
      title: item.title,
      dateFrom: item.startsAt,
      dateTo: item.endsAt ?? item.startsAt,
      description: (notes == null || notes.isEmpty) ? item.title : notes,
      location: item.location,
      price: item.price,
      participantsLimit: item.participantsLimit,
    );
  }

  OutdoorActivityInfo? outdoorByBooking(TrainingBooking booking) {
    final category = categoryForBooking(booking);
    if (category != ActivityCategory.hikes && category != ActivityCategory.trails) {
      return null;
    }
    final type =
        category == ActivityCategory.hikes ? OutdoorActivityType.hike : OutdoorActivityType.trail;
    // Look back from the booking start so recently finished multi-day events
    // are still resolvable for post-trip feedback timing.
    final lookupNow = booking.startsAt.subtract(const Duration(days: 1));
    final items = <OutdoorActivityInfo>[
      ..._scheduleRepository
          .upcomingOutdoorActivities(
            now: lookupNow,
            limit: 100,
          )
          .where((item) => item.type == type),
      if (type == OutdoorActivityType.trail) ..._campsFromTrainings(now: lookupNow),
    ];
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
    return categoryForKeyAndTitle(
      trainingKey: booking.trainingKey,
      trainingTitle: booking.trainingTitle,
    );
  }

  ActivityCategory categoryForKeyAndTitle({
    required String trainingKey,
    required String trainingTitle,
  }) {
    if (trainingTitle.startsWith('🥾 Поход:')) {
      return ActivityCategory.hikes;
    }
    if (trainingTitle.startsWith('🏃 Трейл:') ||
        trainingTitle.startsWith('🎯 Кэмп:') ||
        isCampActivityTitle(trainingTitle)) {
      return ActivityCategory.trails;
    }

    final keyPrefix = trainingKey.split('|').firstOrNull;
    if (keyPrefix != null) {
      for (final category in ActivityCategory.values) {
        if (category.name == keyPrefix) {
          return category;
        }
      }
    }
    return ActivityCategory.trainings;
  }

  TrainingInfo toBookableInfo(OutdoorActivityInfo item) {
    final category =
        item.type == OutdoorActivityType.hike ? ActivityCategory.hikes : ActivityCategory.trails;
    final prefix = item.type == OutdoorActivityType.hike ? '🥾 Поход' : '🎯 Кэмп';
    final location = item.location?.trim();
    return TrainingInfo(
      title: '$prefix: ${item.title}',
      startsAt: item.dateFrom,
      endsAt: item.dateTo,
      location: (location == null || location.isEmpty) ? item.description : location,
      category: category,
      price: item.price,
      prepayPercent: item.prepayPercent,
      participantsLimit: item.participantsLimit,
      includeTrainersInParticipants: true,
      notes: 'Даты: ${dateRangeLabel(item)}',
    );
  }

  List<TrainingInfo> cityFormatHighlights({int upcomingLimit = 24}) {
    TrainingInfo? strength;
    TrainingInfo? boxing;
    TrainingInfo? run;
    for (final item in _scheduleRepository.upcoming(limit: upcomingLimit)) {
      switch (cityFormatKind(item)) {
        case CityFormatKind.strength when strength == null:
          strength = item;
        case CityFormatKind.boxing when boxing == null:
          boxing = item;
        case CityFormatKind.run when run == null:
          run = item;
        case CityFormatKind.strength:
        case CityFormatKind.boxing:
        case CityFormatKind.run:
        case null:
          break;
      }
    }
    return <TrainingInfo>[
      if (strength != null) strength,
      if (boxing != null) boxing,
      if (run != null) run,
    ];
  }

  CityFormatKind? cityFormatKind(TrainingInfo item) {
    final title = item.title.toLowerCase();
    if (isBoxingTrainingTitle(item.title)) {
      return CityFormatKind.boxing;
    }
    if (title.contains('сил')) {
      return CityFormatKind.strength;
    }
    if (title.contains('забег') || title.contains('бег')) {
      return CityFormatKind.run;
    }
    return null;
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
    return 'от $fromLabel до $toLabel';
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  String _normalizeOutdoorTitle(String value) {
    return MessageFormatters.normalizedActivityTitle(value);
  }
}

enum CityFormatKind {
  strength,
  boxing,
  run,
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
