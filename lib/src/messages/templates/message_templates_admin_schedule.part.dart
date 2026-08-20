part of '../message_templates.dart';

extension MessageTemplatesAdminSchedule on MessageTemplates {
  String adminScheduleRoot() {
    return '📅 <b>Расписание</b>\n'
        'Выбери вкладку.';
  }

  String adminScheduleUnavailableStatic() {
    return 'Источник расписания не Google Sheets.\nCRUD недоступен.';
  }

  String adminScheduleWriteDisabled() {
    return 'Запись в таблицу выключена.\nВключи GOOGLE_SHEETS_WRITE_ENABLED и перезапусти бота.';
  }

  String adminScheduleList({
    required ActivityCategory category,
    required int shown,
    required int total,
    required int page,
    required int totalPages,
  }) {
    final title = switch (category) {
      ActivityCategory.trainings => 'Тренировки',
      ActivityCategory.hikes => 'Походы',
      ActivityCategory.trails => 'Трейлы',
    };
    if (total == 0) {
      return '📅 <b>$title</b>\n'
          'Ближайших событий нет.\n'
          'Дальше: ➕ Добавить.';
    }
    final pageLine = totalPages > 1 ? '\nСтраница ${page + 1} из $totalPages.' : '';
    return '📅 <b>$title</b>\n'
        'Ближайшие: $shown из $total.$pageLine\n'
        'Открой карточку или добавь событие.';
  }

  String adminScheduleEventCard(ScheduleCatalogItem item) {
    final lines = <String>['📅 <b>${_escapeHtml(item.title)}</b>'];
    final training = item.training;
    final outdoor = item.outdoor;
    if (training != null) {
      lines.add('🕒 ${_escapeHtml(DateFormat('dd.MM.yyyy HH:mm').format(training.startsAt))}');
      lines.add('📍 ${_escapeHtml(training.location)}');
      final map = training.locationUrl?.trim();
      if (map != null && map.isNotEmpty) {
        lines.add('🗺 ${_escapeHtml(map)}');
      }
      final coach = training.coach?.trim();
      if (coach != null && coach.isNotEmpty) {
        lines.add('🧑‍🏫 ${_escapeHtml(coach)}');
      }
      if (training.price != null) {
        lines.add('💳 ${_escapeHtml(_trainingPriceLabel(training.price))}');
      }
      if (training.participantsLimit != null) {
        lines.add('👥 лимит ${training.participantsLimit}');
      }
      final notes = training.notes?.trim();
      if (notes != null && notes.isNotEmpty) {
        lines.add('📝 ${_escapeHtml(notes)}');
      }
      lines.add(training.includeTrainersInParticipants
          ? 'Тренеры в лимите: да'
          : 'Тренеры в лимите: нет');
      lines.add(training.promoRestricted ? 'Без промокода: да' : 'Без промокода: нет');
    } else if (outdoor != null) {
      lines.add(
          '🕒 ${_escapeHtml(MessageFormatters.outdoorDateLabel(outdoor.dateFrom, outdoor.dateTo))}');
      final location = outdoor.location?.trim();
      if (location != null && location.isNotEmpty) {
        lines.add('📍 ${_escapeHtml(location)}');
      }
      lines.add(_escapeHtml(outdoor.description));
      if (outdoor.price != null) {
        lines.add('💳 ${_escapeHtml(_trainingPriceLabel(outdoor.price))}');
      }
      if (outdoor.prepayPercent != 50) {
        lines.add('Предоплата ${outdoor.prepayPercent}%');
      }
      if (outdoor.participantsLimit != null) {
        lines.add('👥 лимит ${outdoor.participantsLimit}');
      }
      final equipment = outdoor.equipment?.trim();
      if (equipment != null && equipment.isNotEmpty) {
        lines.add('🎒 ${_escapeHtml(equipment)}');
      }
      final itinerary = outdoor.itinerary?.trim();
      if (itinerary != null && itinerary.isNotEmpty) {
        lines.add('🗺 ${_escapeHtml(itinerary)}');
      }
    }
    return lines.join('\n');
  }

  String adminScheduleDeleteConfirm(ScheduleCatalogItem item) {
    return '🗑 <b>Удалить событие?</b>\n'
        '${_escapeHtml(item.title)}\n'
        'Строка пропадёт из таблицы.';
  }

  String adminScheduleFieldPrompt(String field) {
    return switch (field) {
      'title' => 'Название.\nПример: BOXING DVOR.',
      'date' => 'Дата.\nФормат 19.08.2026.',
      'time' => 'Время начала.\nПиши 19:30 или 8:30.',
      'location' => 'Место.\nПример: Стадион Кубань.',
      'map' => 'Ссылка на карту.\nМожно пропустить.',
      'coach' => 'Тренер.\nИмя из штаба или разовое. Можно пропустить.',
      'price' => 'Цена в рублях, число.\nМожно пропустить.',
      'limit' => 'Лимит мест, число.\nМожно пропустить.',
      'notes' => 'Заметки в карточке.\nМожно пропустить.',
      'include_trainers' => 'Считать тренеров в лимите мест?',
      'promo_restricted' => 'Промокод на это событие не действует?',
      'date_from' => 'Дата начала.\nФормат 19.08.2026.',
      'date_to' => 'Дата окончания.\nПусто = один день. Можно пропустить.',
      'description' => 'Описание в карточке.',
      'prepay' => 'Предоплата 1–100.\nПусто = 50%. Можно пропустить.',
      'equipment' => 'Экипировка.\nМожно пропустить.',
      'itinerary' => 'План / тайминг.\nМожно пропустить.',
      _ => 'Введи значение.',
    };
  }

  String adminScheduleCreatePreview(ScheduleEventDraft draft) {
    final lines = <String>['📅 <b>Проверь перед записью</b>'];
    void add(String label, String? value) {
      if (value == null || value.trim().isEmpty) {
        return;
      }
      lines.add('$label ${_escapeHtml(value.trim())}');
    }

    add('Название:', draft.title);
    if (draft.category == ActivityCategory.trainings) {
      add('Дата:', draft.date);
      add('Время:', draft.time);
      add('Место:', draft.location);
      add('Карта:', draft.locationUrl);
      add('Тренер:', draft.coach);
      if (draft.price != null) {
        add('Цена:', '${draft.price} ₽');
      }
      if (draft.participantsLimit != null) {
        add('Лимит:', '${draft.participantsLimit}');
      }
      add('Заметки:', draft.notes);
      if (draft.includeTrainersInParticipants == true) {
        lines.add('Тренеры в лимите: да');
      }
      if (draft.promoRestricted == true) {
        lines.add('Без промокода: да');
      }
    } else {
      add('Дата с:', draft.dateFrom);
      add('Дата по:', draft.dateTo);
      add('Описание:', draft.description);
      add('Место:', draft.location);
      if (draft.price != null) {
        add('Цена:', '${draft.price} ₽');
      }
      if (draft.prepayPercent != null) {
        add('Предоплата:', '${draft.prepayPercent}%');
      }
      if (draft.participantsLimit != null) {
        add('Лимит:', '${draft.participantsLimit}');
      }
      add('Экипировка:', draft.equipment);
      add('План:', draft.itinerary);
    }
    lines.add('Дальше: сохранить или отмена.');
    return lines.join('\n');
  }

  String adminScheduleSaved({required bool refreshOk}) {
    if (refreshOk) {
      return 'Записал в таблицу.\nКарточка в записи уже доступна.';
    }
    return 'Записал в таблицу, кэш бота не обновился.\nДальше: Инструменты → Обновить Google Sheets.';
  }

  String adminScheduleDeleted({required bool refreshOk}) {
    if (refreshOk) {
      return 'Строку удалил из таблицы.';
    }
    return 'Строку удалил из таблицы, кэш бота не обновился.\nДальше: Инструменты → Обновить Google Sheets.';
  }

  String adminScheduleNotFound() => 'Событие не найдено.\nОбнови список.';

  String adminScheduleChooseField() => '✏️ <b>Какое поле меняем?</b>';
}
