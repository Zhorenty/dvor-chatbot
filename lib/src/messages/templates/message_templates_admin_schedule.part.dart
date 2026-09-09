part of '../message_templates.dart';

extension MessageTemplatesAdminSchedule on MessageTemplates {
  String adminScheduleRoot() {
    return RichHtml.screen(
      title: 'Управление расписанием',
      lead: 'Выбери вкладку.',
    );
  }

  String adminScheduleNavHint() {
    return RichHtml.screen(
      title: 'Меню',
      lead: 'Назад — в админ-меню.',
    );
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
      return RichHtml.screen(
        title: title,
        lead: 'Ближайших событий нет.',
        paragraphs: <String>['Дальше: ➕ Добавить.'],
      );
    }
    final pageLine = totalPages > 1 ? 'Страница ${page + 1} из $totalPages.' : null;
    return RichHtml.screen(
      title: title,
      lead: 'Ближайшие: $shown из $total.',
      paragraphs: <String>[
        if (pageLine != null) pageLine,
        'Открой карточку или добавь событие.',
      ],
    );
  }

  String adminScheduleEventCard(ScheduleCatalogItem item) {
    final facts = <String>[];
    String? notes;
    String? description;
    String? equipment;
    String? itinerary;
    final training = item.training;
    final outdoor = item.outdoor;
    if (training != null) {
      facts.add('🕒 ${DateFormat('dd.MM.yyyy HH:mm').format(training.startsAt)}');
      facts.add(
        '📍 ${RichHtml.locationHtml(location: training.location, locationUrl: training.locationUrl)}',
      );
      final coach = training.coach?.trim();
      if (coach != null && coach.isNotEmpty) {
        facts.add('🧑‍🏫 ${_escapeHtml(coach)}');
      }
      if (training.price != null) {
        facts.add('💳 ${_trainingPriceLabel(training.price)}');
      }
      if (training.participantsLimit != null) {
        facts.add('👥 ${training.participantsLimit}');
      }
      notes = training.notes;
      facts.add('Тренеры в лимите: ${training.includeTrainersInParticipants ? 'да' : 'нет'}');
      facts.add('Без промокода: ${training.promoRestricted ? 'да' : 'нет'}');
    } else if (outdoor != null) {
      facts.add('🕒 ${MessageFormatters.outdoorDateLabel(outdoor.dateFrom, outdoor.dateTo)}');
      final location = outdoor.location?.trim();
      if (location != null && location.isNotEmpty) {
        facts.add('📍 ${_escapeHtml(location)}');
      }
      description = outdoor.description;
      if (outdoor.price != null) {
        facts.add('💳 ${_trainingPriceLabel(outdoor.price)}');
      }
      if (outdoor.prepayPercent != 50) {
        facts.add('Предоплата: ${outdoor.prepayPercent}%');
      }
      if (outdoor.participantsLimit != null) {
        facts.add('👥 ${outdoor.participantsLimit}');
      }
      equipment = outdoor.equipment;
      itinerary = outdoor.itinerary;
    }
    return '${RichHtml.screen(title: item.title, facts: facts, alreadyEscaped: true)}'
        '${RichHtml.formattedDetails(summary: 'Заметки', text: notes)}'
        '${RichHtml.formattedDetails(summary: 'Описание', text: description)}'
        '${RichHtml.formattedDetails(summary: 'Экипировка', text: equipment)}'
        '${RichHtml.formattedDetails(summary: 'План', text: itinerary)}';
  }

  String adminScheduleDeleteConfirm(ScheduleCatalogItem item) {
    return RichHtml.screen(
      title: 'Удалить событие',
      lead: item.title,
      paragraphs: <String>['Строка пропадёт из таблицы.'],
    );
  }

  String adminScheduleFieldPrompt(
    String field, {
    int? step,
    int? total,
  }) {
    final body = switch (field) {
      'title' => 'Название.\nПример: BOXING DVOR.',
      'date' => 'Дата.\nФормат 19.08.2026.',
      'time' => 'Время начала.\nПиши 19:30 или 8:30.',
      'location' => 'Место.\nПример: Стадион Кубань.',
      'map' => 'Ссылка на Яндекс Карты.\nМожно пропустить кнопкой.',
      'coach' => 'Тренер.\nИмя из штаба или разовое. Можно пропустить кнопкой.',
      'price' => 'Цена в рублях, число.\nМожно пропустить кнопкой.',
      'limit' => 'Лимит мест, число.\nМожно пропустить кнопкой.',
      'notes' => 'Заметки в карточке.\nМожно пропустить кнопкой.',
      'include_trainers' => 'Считать тренеров в лимите мест?',
      'promo_restricted' => 'Промокод на это событие не действует?',
      'date_from' => 'Дата начала.\nФормат 19.08.2026.',
      'date_to' => 'Дата окончания.\nПусто = один день. Можно пропустить кнопкой.',
      'description' => 'Описание в карточке.',
      'prepay' => 'Предоплата 1–100.\nПусто = 50%. Можно пропустить кнопкой.',
      'equipment' => 'Экипировка.\nМожно пропустить кнопкой.',
      'itinerary' => 'План / тайминг.\nМожно пропустить кнопкой.',
      _ => 'Введи значение.',
    };
    final stepLine = step != null && total != null ? 'Шаг $step из $total.' : null;
    return RichHtml.screen(
      title: stepLine ?? 'Поле',
      lead: body.split('\n').first,
      paragraphs: body.split('\n').skip(1).toList(),
    );
  }

  String adminScheduleCreatePreview(ScheduleEventDraft draft) {
    final rows = <(String, String)>[];
    void add(String label, String? value) {
      if (value == null || value.trim().isEmpty) {
        return;
      }
      rows.add((label, value.trim()));
    }

    add('Название', draft.title);
    String? notes;
    String? description;
    String? equipment;
    String? itinerary;
    if (draft.category == ActivityCategory.trainings) {
      add('Дата', draft.date);
      add('Время', draft.time);
      add('Место', draft.location);
      add('Карта', draft.locationUrl);
      add('Тренер', draft.coach);
      if (draft.price != null) {
        add('Цена', '${draft.price} ₽');
      }
      if (draft.participantsLimit != null) {
        add('Лимит', '${draft.participantsLimit}');
      }
      notes = draft.notes;
      if (draft.includeTrainersInParticipants == true) {
        add('Тренеры в лимите', 'да');
      }
      if (draft.promoRestricted == true) {
        add('Без промокода', 'да');
      }
    } else {
      add('Дата с', draft.dateFrom);
      add('Дата по', draft.dateTo);
      description = draft.description;
      add('Место', draft.location);
      if (draft.price != null) {
        add('Цена', '${draft.price} ₽');
      }
      if (draft.prepayPercent != null) {
        add('Предоплата', '${draft.prepayPercent}%');
      }
      if (draft.participantsLimit != null) {
        add('Лимит', '${draft.participantsLimit}');
      }
      equipment = draft.equipment;
      itinerary = draft.itinerary;
    }
    return '${RichHtml.screen(title: 'Проверь перед записью', rows: rows)}'
        '${RichHtml.formattedDetails(summary: 'Заметки', text: notes)}'
        '${RichHtml.formattedDetails(summary: 'Описание', text: description)}'
        '${RichHtml.formattedDetails(summary: 'Экипировка', text: equipment)}'
        '${RichHtml.formattedDetails(summary: 'План', text: itinerary)}';
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
