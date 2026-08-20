import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';

abstract interface class ScheduleCatalogRepository {
  ScheduleCatalogAvailability get availability;

  Future<List<ScheduleCatalogItem>> listEvents(
    ActivityCategory category, {
    DateTime? now,
    int timezoneOffsetHours = 3,
    bool includePast = false,
  });

  Future<ScheduleCatalogItem> create(ScheduleEventDraft draft);

  Future<ScheduleCatalogItem> update({
    required ScheduleCatalogItem identity,
    required ScheduleEventDraft patch,
  });

  Future<void> delete(ScheduleCatalogItem identity);

  Future<ScheduleRetentionResult> deleteExpired({
    required DateTime now,
    required int timezoneOffsetHours,
  });
}

final class NoopScheduleCatalogRepository implements ScheduleCatalogRepository {
  const NoopScheduleCatalogRepository({
    this.availability = ScheduleCatalogAvailability.staticSource,
  });

  @override
  final ScheduleCatalogAvailability availability;

  ScheduleCatalogFailure get _failure {
    return switch (availability) {
      ScheduleCatalogAvailability.writeDisabled => const ScheduleCatalogFailure(
          ScheduleCatalogErrorCode.writeDisabled,
          'Запись в таблицу выключена.',
        ),
      ScheduleCatalogAvailability.staticSource => const ScheduleCatalogFailure(
          ScheduleCatalogErrorCode.staticSource,
          'Источник расписания не Google Sheets. CRUD недоступен.',
        ),
      ScheduleCatalogAvailability.ready => const ScheduleCatalogFailure(
          ScheduleCatalogErrorCode.writeDisabled,
          'Запись в таблицу выключена.',
        ),
    };
  }

  @override
  Future<List<ScheduleCatalogItem>> listEvents(
    ActivityCategory category, {
    DateTime? now,
    int timezoneOffsetHours = 3,
    bool includePast = false,
  }) async {
    throw _failure;
  }

  @override
  Future<ScheduleCatalogItem> create(ScheduleEventDraft draft) async {
    throw _failure;
  }

  @override
  Future<ScheduleCatalogItem> update({
    required ScheduleCatalogItem identity,
    required ScheduleEventDraft patch,
  }) async {
    throw _failure;
  }

  @override
  Future<void> delete(ScheduleCatalogItem identity) async {
    throw _failure;
  }

  @override
  Future<ScheduleRetentionResult> deleteExpired({
    required DateTime now,
    required int timezoneOffsetHours,
  }) async {
    return const ScheduleRetentionResult();
  }
}
