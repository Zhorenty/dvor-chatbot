import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/rich_html.dart';
import 'package:intl/intl.dart';

final class ScheduleTemplates {
  const ScheduleTemplates();

  String trainings(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    return _indoorActivitiesList(
      title: 'Ближайшие тренировки',
      icon: '🏋️',
      items: items,
      trainers: trainers,
      emptyText: 'Пока тренировок в расписании нет. Загляни позже или выбери другую категорию.',
      includeWeekdayShortInDate: true,
    );
  }

  String _indoorActivitiesList({
    required String title,
    required String icon,
    required List<TrainingInfo> items,
    required List<TrainerInfo> trainers,
    required String emptyText,
    required bool includeWeekdayShortInDate,
  }) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: title,
        lead: emptyText,
      );
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final trainerUsernamesByName = _trainerUsernamesByName(trainers);
    final buffer = StringBuffer(RichHtml.heading(title));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final coach = item.coach?.trim();
      final notes = item.notes?.trim();
      buffer.write('<h3>${index + 1}. $icon ${_escapeHtml(item.title)}</h3>');
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('🕒 Когда', _indoorDateLabel(item.startsAt, formatter, includeWeekdayShortInDate)),
            ('📍 Где', _locationLabel(item)),
            ('👥', _participantsLimitLabel(item.participantsLimit)),
            if (item.price != null) ('💳', MessageFormatters.trainingPriceLabel(item.price)),
            if (coach != null && coach.isNotEmpty)
              (_coachTitle(coach), _coachLabel(coach, trainerUsernamesByName)),
          ],
          alreadyEscaped: true,
        ),
      );
      if (notes != null && notes.isNotEmpty) {
        buffer.write(
          RichHtml.formattedDetails(summary: 'Заметки', text: notes),
        );
      }
    }
    return buffer.toString();
  }

  String hikes(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие походы OUTDVOR 🥾',
      icon: '🥾',
      finalPaymentAfter: 'после похода',
      items: items,
      emptyText: 'Пока походов в расписании нет. Другой формат — в тренировках или трейлах.',
    );
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие трейлы OUTDVOR 🏃',
      icon: '🏃',
      finalPaymentAfter: 'после трейла',
      items: items,
      emptyText: 'Пока трейлов в расписании нет. Другой формат — в тренировках или походах.',
    );
  }

  String chooseScheduleCategory() => RichHtml.screen(
        title: 'Расписание',
        lead: 'Выбери раздел расписания.',
      );

  String hikesEquipment(List<OutdoorActivityInfo> items) {
    return _outdoorEquipmentList(
      title: '🎒 Экипировка для ближайших походов OUTDVOR',
      icon: '🥾',
      items: items,
      emptyText: 'Для ближайших походов список экипировки пока не добавлен.',
    );
  }

  String trailsEquipment(List<OutdoorActivityInfo> items) {
    return _outdoorEquipmentList(
      title: '🎒 Экипировка для ближайших трейлов OUTDVOR',
      icon: '🏃',
      items: items,
      emptyText: 'Для ближайших трейлов список экипировки пока не добавлен.',
    );
  }

  String hikesItinerary(List<OutdoorActivityInfo> items) {
    return _outdoorItineraryList(
      title: '🗺 Расписание ближайших походов OUTDVOR',
      icon: '🥾',
      items: items,
      emptyText: 'Для ближайших походов расписание пока не добавлено.',
    );
  }

  String trailsItinerary(List<OutdoorActivityInfo> items) {
    return _outdoorItineraryList(
      title: '🗺 Расписание ближайших трейлов OUTDVOR',
      icon: '🏃',
      items: items,
      emptyText: 'Для ближайших трейлов расписание пока не добавлено.',
    );
  }

  String outdoorPostPaymentRecap(OutdoorActivityInfo item) {
    return '${RichHtml.heading('Орг-напоминание перед стартом')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Событие', item.title),
        ('🕒 Когда', MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)),
      ],
    )}'
        '${RichHtml.formattedDetails(
      summary: 'Расписание похода',
      text: item.itinerary,
      empty: 'Тайминг скоро добавим. Следи за обновлениями в чате.',
    )}'
        '${RichHtml.formattedDetails(
      summary: 'Экипировка',
      text: item.equipment,
      empty: 'Список экипировки скоро добавим. Следи за обновлениями в чате.',
    )}';
  }

  String chooseOutdoorEventForDetails(ActivityCategory category) {
    final categoryLabel = category == ActivityCategory.hikes ? 'поход' : 'трейл';
    return RichHtml.screen(
      title: 'Событие',
      lead: 'Выбери $categoryLabel.',
    );
  }

  String chooseOutdoorDetailType(OutdoorActivityInfo item) {
    final location = item.location?.trim();
    final buffer = StringBuffer()
      ..write(RichHtml.heading(item.title))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('🕒 Когда', MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)),
            if (location != null && location.isNotEmpty) ('📍 Где', location),
            if (item.price != null)
              (
                '💳',
                _outdoorPriceWithPrepayment(item.price!, prepayPercent: item.prepayPercent),
              ),
          ],
        ),
      )
      ..write(RichHtml.formattedDetails(summary: 'Описание', text: item.description))
      ..write(RichHtml.paragraph('Выбери действие.'));
    return buffer.toString();
  }

  String unknownOutdoorSelection() {
    return RichHtml.screen(
      title: 'Не распознал',
      lead: 'Выбери событие кнопкой из списка.',
    );
  }

  String outdoorEquipmentDetails(OutdoorActivityInfo item) {
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Экипировка'))
      ..write(RichHtml.paragraph(item.title))
      ..write(RichHtml.paragraph(MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)));
    final equipment = item.equipment?.trim();
    if (equipment == null || equipment.isEmpty) {
      buffer.write(RichHtml.paragraph('Список экипировки ещё не добавлен.'));
    } else {
      buffer.write(RichHtml.formatted(item.equipment!));
    }
    return buffer.toString();
  }

  String outdoorItineraryDetails(OutdoorActivityInfo item) {
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Расписание похода'))
      ..write(RichHtml.paragraph(item.title))
      ..write(RichHtml.paragraph(MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)));
    final itinerary = item.itinerary?.trim();
    if (itinerary == null || itinerary.isEmpty) {
      buffer.write(RichHtml.paragraph('Тайминг ещё не добавлен.'));
    } else {
      buffer.write(RichHtml.formatted(item.itinerary!));
    }
    return buffer.toString();
  }

  String noUpcomingForBooking() => RichHtml.screen(
        title: 'Пока пусто',
        lead: 'Ближайших мероприятий для записи нет.',
        paragraphs: <String>['Другой формат — в соседней категории.'],
      );

  String coachingStaff(List<TrainerInfo> trainers) {
    if (trainers.isEmpty) {
      return RichHtml.screen(
        title: 'Штаб',
        lead: 'Список тренеров пока пуст. Загляни позже.',
      );
    }
    final buffer = StringBuffer(RichHtml.heading('Тренерский штаб'));
    buffer.write(RichHtml.paragraph('Карточка — кнопкой «Подробнее о тренере».'));
    var didWriteTeamHeader = false;
    for (var index = 0; index < trainers.length; index++) {
      final trainer = trainers[index];
      if (trainer.kind == StaffKind.team && !didWriteTeamHeader) {
        didWriteTeamHeader = true;
        buffer.write(RichHtml.heading('Команда DVOR', level: 3));
      }
      buffer.write(RichHtml.heading('${index + 1}. ${trainer.name}', level: 3));
      final role = _normalizeTrainerRole(trainer.role);
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            if (role.isNotEmpty) ('Направление', _escapeHtml(role)),
            ('Контакт', _trainerLinkLabel(trainer.link)),
          ],
          alreadyEscaped: true,
        ),
      );
    }
    return buffer.toString();
  }

  String chooseTrainerProfile(List<TrainerInfo> trainers) {
    if (trainers.isEmpty) {
      return RichHtml.screen(
        title: 'Штаб',
        lead: 'Список тренеров пока пуст. Загляни позже.',
      );
    }
    return RichHtml.screen(
      title: 'Тренер',
      lead: 'Выбери имя из списка.',
    );
  }

  String trainerProfile(TrainerInfo trainer) {
    final role = _normalizeTrainerRole(trainer.role);
    final buffer = StringBuffer(RichHtml.heading(trainer.name));
    buffer.write(
      RichHtml.table(
        <(String, String)>[
          if (role.isNotEmpty) ('Направление', _escapeHtml(role)),
          ('Контакт', _trainerLinkLabel(trainer.link)),
        ],
        alreadyEscaped: true,
      ),
    );
    buffer.write(
      RichHtml.formattedDetails(
        summary: trainer.kind == StaffKind.team ? 'О команде' : 'О тренере',
        text: trainer.description,
        empty: 'Описание скоро добавим.',
      ),
    );
    return buffer.toString();
  }

  String unknownTrainerSelection() => RichHtml.screen(
        title: 'Не распознал',
        lead: 'Выбери тренера кнопкой из списка.',
      );

  String scheduleRefreshDone({bool exportQueued = false}) {
    if (exportQueued) {
      return 'Входящие листы обновлены.\n'
          'Срезы FUNNEL и АНАЛИТИКА поставлены в очередь.\n'
          'Открой таблицу через минуту.';
    }
    return 'Готово! Google Sheets обновлён ✅\nОбновил расписание и список тренеров.';
  }

  String scheduleRefreshFailed({bool exportQueued = false}) {
    if (exportQueued) {
      return 'Входящие листы не обновились — оставил последние данные.\n'
          'Срезы в таблице всё равно поставлены в очередь.\n'
          'Проверь таблицу через минуту.';
    }
    return 'Не получилось обновить Google Sheets 😔 Использую последние сохраненные данные.';
  }

  String scheduleDocumentLink() =>
      'Актуальный Google Sheets:\nhttps://docs.google.com/spreadsheets/d/1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q/edit?gid=0#gid=0';

  String _outdoorActivitiesList({
    required String title,
    required String icon,
    required String finalPaymentAfter,
    required List<OutdoorActivityInfo> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: title,
        lead: emptyText,
      );
    }
    final buffer = StringBuffer(RichHtml.heading(title));
    buffer.write(RichHtml.paragraph(_outdoorPaymentRuleLine(items, finalPaymentAfter)));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final location = item.location?.trim();
      buffer.write('<h3>${index + 1}. $icon ${_escapeHtml(item.title)}</h3>');
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('🕒 Когда', MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)),
            if (location != null && location.isNotEmpty) ('📍 Где', location),
            if (item.price != null)
              (
                '💳',
                _outdoorPriceWithPrepayment(item.price!, prepayPercent: item.prepayPercent),
              ),
          ],
        ),
      );
      buffer.write(RichHtml.formattedDetails(summary: 'Описание', text: item.description));
    }
    return buffer.toString();
  }

  String _outdoorEquipmentList({
    required String title,
    required String icon,
    required List<OutdoorActivityInfo> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: title,
        lead: emptyText,
      );
    }
    final buffer = StringBuffer(RichHtml.heading(title));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write('<h3>${index + 1}. $icon ${_escapeHtml(item.title)}</h3>');
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('🕒 Когда', MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)),
          ],
        ),
      );
      buffer.write(
        RichHtml.formattedDetails(
          summary: 'Экипировка',
          text: item.equipment,
          empty: 'Список скоро добавим. Следи за обновлениями в чате.',
        ),
      );
    }
    return buffer.toString();
  }

  String _outdoorItineraryList({
    required String title,
    required String icon,
    required List<OutdoorActivityInfo> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: title,
        lead: emptyText,
      );
    }
    final buffer = StringBuffer(RichHtml.heading(title));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write('<h3>${index + 1}. $icon ${_escapeHtml(item.title)}</h3>');
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('🕒 Когда', MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)),
          ],
        ),
      );
      buffer.write(
        RichHtml.formattedDetails(
          summary: 'Расписание',
          text: item.itinerary,
          empty: 'Тайминг скоро добавим. Следи за обновлениями в чате.',
        ),
      );
    }
    return buffer.toString();
  }

  String _trainerLinkLabel(String rawLink) {
    final username = _extractTelegramUsername(rawLink);
    if (username != null && username.isNotEmpty) {
      final escapedUsername = _escapeHtml(username);
      return '<a href="https://t.me/$escapedUsername">@$escapedUsername</a>';
    }
    return _escapeHtml(rawLink.trim());
  }

  String _locationLabel(TrainingInfo item) {
    final location = item.location.trim();
    final link = item.locationUrl?.trim();
    if (link != null && link.isNotEmpty) {
      final escapedLink = _escapeHtml(link);
      return '<a href="$escapedLink">${_escapeHtml(location)}</a>';
    }
    return _escapeHtml(location);
  }

  String _participantsLimitLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return 'без лимита';
    }
    return '$participantsLimit мест';
  }

  String _indoorDateLabel(
    DateTime value,
    DateFormat formatter,
    bool includeWeekdayShortInDate,
  ) {
    final formattedDate = formatter.format(value);
    if (!includeWeekdayShortInDate) {
      return formattedDate;
    }
    final weekday = switch (value.weekday) {
      DateTime.monday => 'пн',
      DateTime.tuesday => 'вт',
      DateTime.wednesday => 'ср',
      DateTime.thursday => 'чт',
      DateTime.friday => 'пт',
      DateTime.saturday => 'сб',
      DateTime.sunday => 'вс',
      _ => '',
    };
    return weekday.isEmpty ? formattedDate : '$weekday, $formattedDate';
  }

  String _coachTitle(String coach) {
    final lowerCoach = coach.toLowerCase();
    if (lowerCoach.contains('команда') ||
        lowerCoach.contains('тренерский штаб') ||
        lowerCoach.contains('несколько')) {
      return '🧑‍🏫 Тренеры:';
    }
    final normalized = lowerCoach.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasExplicitListSeparators = normalized.contains(',') ||
        normalized.contains(';') ||
        normalized.contains('/') ||
        normalized.contains(' и ') ||
        normalized.contains(' & ') ||
        normalized.contains(' + ');
    if (hasExplicitListSeparators) {
      return '🧑‍🏫 Тренеры:';
    }
    return '🧑‍🏫 Тренер:';
  }

  String _coachLabel(String coach, Map<String, String> trainerUsernamesByName) {
    if (trainerUsernamesByName.isEmpty) {
      return _escapeHtml(coach);
    }

    final names = trainerUsernamesByName.keys.toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));
    if (names.isEmpty) {
      return _escapeHtml(coach);
    }

    final escapedNames = names.map(RegExp.escape).join('|');
    final pattern = RegExp(
      r'(^|[^A-Za-zА-Яа-яЁё0-9])(' + escapedNames + r')(?=$|[^A-Za-zА-Яа-яЁё0-9])',
      caseSensitive: false,
    );

    final buffer = StringBuffer();
    var lastIndex = 0;
    for (final match in pattern.allMatches(coach)) {
      final boundary = match.group(1) ?? '';
      final matchedName = match.group(2);
      if (matchedName == null) {
        continue;
      }
      final normalized = _normalizeName(matchedName);
      final username = trainerUsernamesByName[normalized];
      if (username == null) {
        continue;
      }

      buffer.write(_escapeHtml(coach.substring(lastIndex, match.start)));
      buffer.write(_escapeHtml(boundary));
      final escapedUsername = _escapeHtml(username);
      final escapedName = _escapeHtml(matchedName);
      buffer.write('<a href="https://t.me/$escapedUsername">$escapedName</a>');
      lastIndex = match.end;
    }

    if (lastIndex == 0) {
      return _escapeHtml(coach);
    }
    buffer.write(_escapeHtml(coach.substring(lastIndex)));
    return buffer.toString();
  }

  Map<String, String> _trainerUsernamesByName(List<TrainerInfo> trainers) {
    final result = <String, String>{};
    for (final trainer in trainers) {
      final normalizedName = _normalizeName(trainer.name);
      if (normalizedName.isEmpty || result.containsKey(normalizedName)) {
        continue;
      }
      final username = _extractTelegramUsername(trainer.link);
      if (username == null || username.isEmpty) {
        continue;
      }
      result[normalizedName] = username;
    }
    return result;
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _extractTelegramUsername(String rawLink) {
    final trimmed = rawLink.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('@')) {
      final value = _sanitizeTelegramUsername(trimmed.substring(1));
      return value.isEmpty ? null : value;
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final candidateUri = Uri.tryParse('https://$trimmed');
      final host = candidateUri?.host.toLowerCase();
      if (host == 't.me' ||
          host == 'www.t.me' ||
          host == 'telegram.me' ||
          host == 'www.telegram.me') {
        final segment = candidateUri!.pathSegments.isEmpty ? '' : candidateUri.pathSegments.first;
        final value = _sanitizeTelegramUsername(segment);
        return value.isEmpty ? null : value;
      }
      final value = _sanitizeTelegramUsername(trimmed);
      return value.isEmpty ? null : value;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 't.me' &&
        host != 'www.t.me' &&
        host != 'telegram.me' &&
        host != 'www.telegram.me') {
      return null;
    }
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    final value = _sanitizeTelegramUsername(segment);
    return value.isEmpty ? null : value;
  }

  String _sanitizeTelegramUsername(String raw) {
    var value = raw.trim();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex >= 0) {
      value = value.substring(0, queryIndex);
    }
    final hashIndex = value.indexOf('#');
    if (hashIndex >= 0) {
      value = value.substring(0, hashIndex);
    }
    if (value.contains('/')) {
      value = value.split('/').first;
    }
    return value.trim();
  }

  String _escapeHtml(String value) => escapeHtml(value);

  String _normalizeTrainerRole(String raw) {
    return raw.replaceAll('\r\n', '\n').replaceAll('\n', ' ').trim();
  }

  String _outdoorPaymentRuleLine(List<OutdoorActivityInfo> items, String finalPaymentAfter) {
    final percents = items.map((item) => item.prepayPercent).toSet();
    if (percents.length == 1) {
      final percent = MessageFormatters.resolveOutdoorPrepayPercent(percents.single);
      final remainder = MessageFormatters.outdoorRemainderPercent(percent);
      return 'Оплата: $percent% предоплата при записи, оставшиеся $remainder% — '
          '$finalPaymentAfter.';
    }
    return 'Оплата: предоплата при записи (доля указана у каждого события), '
        'остаток — $finalPaymentAfter.';
  }

  String _outdoorPriceWithPrepayment(int price, {int prepayPercent = 50}) {
    final percent = MessageFormatters.resolveOutdoorPrepayPercent(prepayPercent);
    final totalLabel = MessageFormatters.trainingPriceLabel(price);
    final prepaymentLabel = MessageFormatters.trainingPriceLabel(
      MessageFormatters.outdoorPrepaymentAmount(price, prepayPercent: percent),
    );
    return '$totalLabel ($prepaymentLabel предоплата $percent%)';
  }
}
