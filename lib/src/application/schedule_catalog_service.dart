import 'package:dvor_chatbot/src/data/google_sheets_value_parser.dart';
import 'package:dvor_chatbot/src/data/schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';

final class ScheduleCatalogService {
  ScheduleCatalogService({
    required ScheduleCatalogRepository catalogRepository,
    required TrainingScheduleRepository scheduleRepository,
    DateTime Function()? nowProvider,
    this.timezoneOffsetHours = 3,
  })  : _catalogRepository = catalogRepository,
        _scheduleRepository = scheduleRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  final ScheduleCatalogRepository _catalogRepository;
  final TrainingScheduleRepository _scheduleRepository;
  final DateTime Function() _nowProvider;
  final int timezoneOffsetHours;

  ScheduleCatalogAvailability get availability => _catalogRepository.availability;

  bool get canEdit => availability == ScheduleCatalogAvailability.ready;

  Future<List<ScheduleCatalogItem>> listItems(ActivityCategory category) async {
    if (availability != ScheduleCatalogAvailability.ready) {
      throw ScheduleCatalogFailure(
        availability == ScheduleCatalogAvailability.staticSource
            ? ScheduleCatalogErrorCode.staticSource
            : ScheduleCatalogErrorCode.writeDisabled,
      );
    }
    return _catalogRepository.listEvents(
      category,
      now: _nowProvider(),
      timezoneOffsetHours: timezoneOffsetHours,
    );
  }

  String? validateField({
    required ActivityCategory category,
    required String field,
    required String raw,
  }) {
    final value = raw.trim();
    switch (field) {
      case 'title':
        return value.isEmpty ? 'Нужно название.' : null;
      case 'date':
      case 'date_from':
      case 'date_to':
        if (value.isEmpty) {
          return field == 'date_to' ? null : 'Дата в формате 19.08.2026.';
        }
        if (GoogleSheetsValueParser.parseDate(value) == null) {
          return 'Дата не разобралась. Формат 19.08.2026.';
        }
        return null;
      case 'time':
        if (value.isEmpty) {
          return 'Время в формате 19:30 или 8:30.';
        }
        if (GoogleSheetsValueParser.parseTime(value) == null) {
          return 'Время не разобралось. Пиши 19:30 или 8:30.';
        }
        return null;
      case 'location':
        if (category == ActivityCategory.trainings && value.isEmpty) {
          return 'Нужно место.';
        }
        return null;
      case 'description':
        return value.isEmpty ? 'Нужно описание.' : null;
      case 'price':
      case 'limit':
        if (value.isEmpty) {
          return null;
        }
        final parsed = field == 'limit'
            ? GoogleSheetsValueParser.parseParticipantsLimit(value)
            : GoogleSheetsValueParser.parsePrice(value);
        if (parsed == null) {
          return field == 'limit'
              ? 'Лимит — целое число больше 0.'
              : 'Цена — целое число в рублях.';
        }
        return null;
      case 'prepay':
        if (value.isEmpty) {
          return null;
        }
        if (GoogleSheetsValueParser.parsePrepayPercentOrNull(value) == null) {
          return 'Предоплата — число от 1 до 100.';
        }
        return null;
      case 'map':
        if (value.isEmpty) {
          return null;
        }
        final lower = value.toLowerCase();
        if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
          return 'Ссылка на карту должна начинаться с http.';
        }
        return null;
      default:
        return null;
    }
  }

  ScheduleEventDraft applyField({
    required ScheduleEventDraft draft,
    required String field,
    required String raw,
  }) {
    final value = raw.trim();
    switch (field) {
      case 'title':
        return draft.copyWith(title: value);
      case 'date':
        return draft.copyWith(date: value);
      case 'time':
        return draft.copyWith(time: value);
      case 'location':
        return draft.copyWith(location: value);
      case 'map':
        return draft.copyWith(locationUrl: value);
      case 'coach':
        return draft.copyWith(coach: value);
      case 'price':
        return draft.copyWith(price: GoogleSheetsValueParser.parsePrice(value));
      case 'limit':
        return draft.copyWith(
          participantsLimit: GoogleSheetsValueParser.parseParticipantsLimit(value),
        );
      case 'notes':
        return draft.copyWith(notes: value);
      case 'date_from':
        return draft.copyWith(dateFrom: value);
      case 'date_to':
        return draft.copyWith(dateTo: value, clearDateTo: value.isEmpty);
      case 'description':
        return draft.copyWith(description: value);
      case 'prepay':
        return draft.copyWith(
          prepayPercent: GoogleSheetsValueParser.parsePrepayPercentOrNull(value),
          clearPrepay: value.isEmpty,
        );
      case 'equipment':
        return draft.copyWith(equipment: value);
      case 'itinerary':
        return draft.copyWith(itinerary: value);
      default:
        return draft;
    }
  }

  Future<ScheduleCatalogWriteResult> create(ScheduleEventDraft draft) {
    return _mutate(() => _catalogRepository.create(draft));
  }

  Future<ScheduleCatalogWriteResult> update({
    required ScheduleCatalogItem identity,
    required ScheduleEventDraft patch,
  }) {
    return _mutate(() => _catalogRepository.update(identity: identity, patch: patch));
  }

  Future<ScheduleCatalogWriteResult> delete(ScheduleCatalogItem identity) {
    return _mutate(() async {
      await _catalogRepository.delete(identity);
      return identity;
    });
  }

  Future<ScheduleRetentionResult> purgeExpired() {
    if (availability != ScheduleCatalogAvailability.ready) {
      return Future<ScheduleRetentionResult>.value(const ScheduleRetentionResult());
    }
    return _catalogRepository.deleteExpired(
      now: _nowProvider(),
      timezoneOffsetHours: timezoneOffsetHours,
    );
  }

  Future<bool> refreshSchedule() => _scheduleRepository.refresh(force: true);

  Future<ScheduleCatalogWriteResult> _mutate(
    Future<ScheduleCatalogItem> Function() action,
  ) async {
    if (availability != ScheduleCatalogAvailability.ready) {
      return _availabilityError();
    }
    try {
      final item = await action();
      final refreshOk = await _scheduleRepository.refresh(force: true);
      return ScheduleCatalogWriteResult(item: item, refreshOk: refreshOk);
    } on ScheduleCatalogFailure catch (error) {
      return ScheduleCatalogWriteResult(error: error.code, message: error.message);
    }
  }

  ScheduleCatalogWriteResult _availabilityError() {
    if (availability == ScheduleCatalogAvailability.staticSource) {
      return const ScheduleCatalogWriteResult(
        error: ScheduleCatalogErrorCode.staticSource,
        message: 'Источник расписания не Google Sheets. CRUD недоступен.',
      );
    }
    return const ScheduleCatalogWriteResult(
      error: ScheduleCatalogErrorCode.writeDisabled,
      message: 'Запись в таблицу выключена.',
    );
  }
}
