import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:intl/intl.dart';

final class ScheduleTemplates {
  const ScheduleTemplates();

  String trainings(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    return _indoorActivitiesList(
      title: 'Ближайшие тренировки DVOR 💪',
      icon: '🏋️',
      items: items,
      trainers: trainers,
      emptyText: 'Пока тренировок в расписании нет 😌 Скоро добавим новые даты!',
    );
  }

  String yoga(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    final list = _indoorActivitiesList(
      title: 'Ближайшая йога DVOR 🧘',
      icon: '🧘',
      items: items,
      trainers: trainers,
      emptyText: 'Пока йоги в расписании нет 😌 Скоро добавим новые даты!',
    );
    return '$list\n\n'
        'По вопросам теории и практики можно написать тренеру-йоги.\n'
        'По организационным вопросам: @dvor_support.';
  }

  String _indoorActivitiesList({
    required String title,
    required String icon,
    required List<TrainingInfo> items,
    required List<TrainerInfo> trainers,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return emptyText;
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final trainerUsernamesByName = _trainerUsernamesByName(trainers);
    final lines = <String>['<b>${_escapeHtml(title)}</b>'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final coach = item.coach?.trim();
      final notes = item.notes?.trim();

      lines.addAll(<String>[
        '',
        '🏷 <b>${index + 1}. $icon ${_escapeHtml(item.title)}</b>',
        '🕒 ${formatter.format(item.startsAt)}',
        '📍 ${_locationLabel(item)}',
        '👥 ${_participantsLimitLabel(item.participantsLimit)}',
        if (item.price != null) '💳 ${MessageFormatters.trainingPriceLabel(item.price)}',
        if (coach != null && coach.isNotEmpty)
          '🧑‍🏫 ${_coachTitle(coach)}: ${_coachLabel(coach, trainerUsernamesByName)}',
        if (notes != null && notes.isNotEmpty) '📝 ${_escapeHtml(notes)}',
      ]);
    }
    return lines.join('\n');
  }

  String hikes(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие походы OUTDVOR 🥾',
      icon: '🥾',
      items: items,
      emptyText: 'Пока походов в расписании нет 😌',
    );
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие трейлы OUTDVOR 🏃',
      icon: '🏃',
      items: items,
      emptyText: 'Пока трейлов в расписании нет 😌',
    );
  }

  String chooseScheduleCategory() => 'Выбери раздел расписания 👇';

  String noUpcomingForBooking() => 'Пока нет ближайших мероприятий для записи 😌';

  String coachingStaff(List<TrainerInfo> trainers) {
    if (trainers.isEmpty) {
      return 'Список тренеров пока пуст. Попробуй чуть позже 🙏';
    }
    final lines = <String>[
      '🧑‍🏫 <b>Тренерский штаб DVOR</b>',
      'Выбери «Подробнее о тренере», чтобы открыть карточку 👇',
    ];
    for (var index = 0; index < trainers.length; index++) {
      final trainer = trainers[index];
      final role = _normalizeTrainerRole(trainer.role);
      lines.addAll(<String>[
        '',
        '👤 <b>${index + 1}. ${_escapeHtml(trainer.name)}</b>',
        if (role.isNotEmpty) '🎯 ${_escapeHtml(role)}',
        '🔗 ${_trainerLinkLabel(trainer.link)}',
      ]);
    }
    return lines.join('\n');
  }

  String chooseTrainerProfile(List<TrainerInfo> trainers) {
    if (trainers.isEmpty) {
      return 'Список тренеров пока пуст. Попробуй чуть позже 🙏';
    }
    return 'Выбери тренера из списка ниже 👇';
  }

  String trainerProfile(TrainerInfo trainer) {
    final description =
        _normalizeTrainerDescription(trainer.description).split('\n').map(_escapeHtml).join('\n');
    final role = _normalizeTrainerRole(trainer.role);
    return <String>[
      '🧑‍🏫 <b>${_escapeHtml(trainer.name)}</b>',
      if (role.isNotEmpty) '🎯 <b>Направление:</b> ${_escapeHtml(role)}',
      '🔗 <b>Контакт:</b> ${_trainerLinkLabel(trainer.link)}',
      '📝 <b>О тренере:</b>',
      description,
    ].join('\n');
  }

  String unknownTrainerSelection() => 'Не смог распознать тренера. Выбери кнопку из списка 👇';

  String scheduleRefreshDone() =>
      'Готово! Google Docs обновил ✅\nОбновил расписание и список тренеров.';

  String scheduleRefreshFailed() =>
      'Не получилось обновить Google Docs 😔 Использую последние сохраненные данные.';

  String scheduleDocumentLink() =>
      'Актуальный Google Docs:\nhttps://docs.google.com/spreadsheets/d/1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q/edit?gid=0#gid=0';

  String _outdoorActivitiesList({
    required String title,
    required String icon,
    required List<OutdoorActivityInfo> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return emptyText;
    }
    final lines = <String>['<b>${_escapeHtml(title)}</b>'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.addAll(<String>[
        '',
        '🏷 <b>${index + 1}. $icon ${_escapeHtml(item.title)}</b>',
        '🕒 ${MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)}',
        if (item.price != null) '💳 ${MessageFormatters.trainingPriceLabel(item.price)}',
        if (item.description.trim().isNotEmpty) '📝 ${_escapeHtml(item.description.trim())}',
      ]);
    }
    return lines.join('\n');
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

  String _coachTitle(String coach) {
    final lowerCoach = coach.toLowerCase();
    if (lowerCoach.contains('команда') ||
        lowerCoach.contains('тренерский штаб') ||
        lowerCoach.contains('несколько')) {
      return 'Тренеры';
    }
    final normalized = lowerCoach.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasExplicitListSeparators = normalized.contains(',') ||
        normalized.contains(';') ||
        normalized.contains('/') ||
        normalized.contains(' и ') ||
        normalized.contains(' & ') ||
        normalized.contains(' + ');
    if (hasExplicitListSeparators) {
      return 'Тренеры';
    }
    return 'Тренер';
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

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _normalizeTrainerDescription(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final rawLines = normalized.split('\n').map((line) => line.trim()).toList(growable: false);
    if (rawLines.every((line) => line.isEmpty)) {
      return 'Описание скоро добавим.';
    }

    final lines = <String>[];
    var previousWasEmpty = false;
    for (final line in rawLines) {
      final isEmpty = line.isEmpty;
      if (isEmpty) {
        if (!previousWasEmpty && lines.isNotEmpty) {
          lines.add('');
        }
        previousWasEmpty = true;
        continue;
      }
      lines.add(line);
      previousWasEmpty = false;
    }

    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n');
  }

  String _normalizeTrainerRole(String raw) {
    return raw.replaceAll('\r\n', '\n').replaceAll('\n', ' ').trim();
  }
}
