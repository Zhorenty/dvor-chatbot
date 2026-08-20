import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

enum ScheduleCatalogAvailability {
  ready,
  writeDisabled,
  staticSource,
}

enum ScheduleCatalogErrorCode {
  writeDisabled,
  staticSource,
  notFound,
  noEmptyRows,
  invalidValue,
  sheetMissing,
}

final class ScheduleCatalogFailure implements Exception {
  const ScheduleCatalogFailure(this.code, [this.message]);

  final ScheduleCatalogErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

final class ScheduleCatalogItem {
  const ScheduleCatalogItem({
    required this.sheetRow,
    required this.category,
    this.training,
    this.outdoor,
  });

  final int sheetRow;
  final ActivityCategory category;
  final TrainingInfo? training;
  final OutdoorActivityInfo? outdoor;

  String get title => training?.title ?? outdoor?.title ?? '';

  String? get location => training?.location ?? outdoor?.location;

  DateTime get sortAt => training?.startsAt ?? outdoor!.dateFrom;

  DateTime get endsAt {
    if (training != null) {
      return training!.startsAt;
    }
    return outdoor!.dateTo;
  }

  bool get isTraining => category == ActivityCategory.trainings && training != null;

  bool matchesIdentity(ScheduleCatalogItem other) {
    if (category != other.category) {
      return false;
    }
    if (title.trim().toLowerCase() != other.title.trim().toLowerCase()) {
      return false;
    }
    final ownTraining = training;
    final otherTraining = other.training;
    if (ownTraining != null && otherTraining != null) {
      return _sameDateTime(ownTraining.startsAt, otherTraining.startsAt) &&
          ownTraining.location.trim().toLowerCase() == otherTraining.location.trim().toLowerCase();
    }
    final ownOutdoor = outdoor;
    final otherOutdoor = other.outdoor;
    if (ownOutdoor != null && otherOutdoor != null) {
      return _sameDay(ownOutdoor.dateFrom, otherOutdoor.dateFrom);
    }
    return false;
  }

  static bool _sameDateTime(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

final class ScheduleEventDraft {
  const ScheduleEventDraft({
    required this.category,
    this.title,
    this.date,
    this.time,
    this.location,
    this.locationUrl,
    this.coach,
    this.price,
    this.participantsLimit,
    this.notes,
    this.includeTrainersInParticipants,
    this.promoRestricted,
    this.dateFrom,
    this.dateTo,
    this.clearDateTo = false,
    this.description,
    this.prepayPercent,
    this.clearPrepay = false,
    this.equipment,
    this.itinerary,
  });

  final ActivityCategory category;
  final String? title;
  final String? date;
  final String? time;
  final String? location;
  final String? locationUrl;
  final String? coach;
  final int? price;
  final int? participantsLimit;
  final String? notes;
  final bool? includeTrainersInParticipants;
  final bool? promoRestricted;
  final String? dateFrom;
  final String? dateTo;
  final bool clearDateTo;
  final String? description;
  final int? prepayPercent;
  final bool clearPrepay;
  final String? equipment;
  final String? itinerary;

  ScheduleEventDraft copyWith({
    ActivityCategory? category,
    String? title,
    String? date,
    String? time,
    String? location,
    String? locationUrl,
    String? coach,
    int? price,
    int? participantsLimit,
    String? notes,
    bool? includeTrainersInParticipants,
    bool? promoRestricted,
    String? dateFrom,
    String? dateTo,
    bool? clearDateTo,
    String? description,
    int? prepayPercent,
    bool? clearPrepay,
    String? equipment,
    String? itinerary,
  }) {
    return ScheduleEventDraft(
      category: category ?? this.category,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      locationUrl: locationUrl ?? this.locationUrl,
      coach: coach ?? this.coach,
      price: price ?? this.price,
      participantsLimit: participantsLimit ?? this.participantsLimit,
      notes: notes ?? this.notes,
      includeTrainersInParticipants:
          includeTrainersInParticipants ?? this.includeTrainersInParticipants,
      promoRestricted: promoRestricted ?? this.promoRestricted,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      clearDateTo: clearDateTo ?? this.clearDateTo,
      description: description ?? this.description,
      prepayPercent: prepayPercent ?? this.prepayPercent,
      clearPrepay: clearPrepay ?? this.clearPrepay,
      equipment: equipment ?? this.equipment,
      itinerary: itinerary ?? this.itinerary,
    );
  }
}

String scheduleCategoryCode(ActivityCategory category) {
  return switch (category) {
    ActivityCategory.trainings => 't',
    ActivityCategory.hikes => 'h',
    ActivityCategory.trails => 'r',
  };
}

ActivityCategory? scheduleCategoryFromCode(String code) {
  return switch (code) {
    't' => ActivityCategory.trainings,
    'h' => ActivityCategory.hikes,
    'r' => ActivityCategory.trails,
    _ => null,
  };
}

final class ScheduleRetentionResult {
  const ScheduleRetentionResult({
    this.trainingsDeleted = 0,
    this.hikesDeleted = 0,
    this.trailsDeleted = 0,
    this.requestedSheetTitles = const <String>[],
  });

  final int trainingsDeleted;
  final int hikesDeleted;
  final int trailsDeleted;
  final List<String> requestedSheetTitles;

  int get totalDeleted => trainingsDeleted + hikesDeleted + trailsDeleted;
}

final class ScheduleCatalogWriteResult {
  const ScheduleCatalogWriteResult({
    this.item,
    this.error,
    this.message,
    this.refreshOk = true,
  });

  final ScheduleCatalogItem? item;
  final ScheduleCatalogErrorCode? error;
  final String? message;
  final bool refreshOk;

  bool get isOk => error == null;
}
