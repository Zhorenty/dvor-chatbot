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
    final lines = <String>[title];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final coach = item.coach?.trim();
      final notes = item.notes?.trim();

      lines.addAll(<String>[
        '',
        '• $icon ${_escapeHtml(item.title)}',
        '   🕒 Когда: ${formatter.format(item.startsAt)}',
        '   📍 Где: ${_locationLabel(item)}',
        '   👥 Участники: ${_participantsLimitLabel(item.participantsLimit)}',
        if (item.price != null) '   💳 Взнос: ${MessageFormatters.trainingPriceLabel(item.price)}',
        if (coach != null && coach.isNotEmpty)
          '   🧑‍🏫 ${_coachTitle(coach)}: ${_coachLabel(coach, trainerUsernamesByName)}',
        if (notes != null && notes.isNotEmpty) '   📝 Примечание: ${_escapeHtml(notes)}',
      ]);

      if (index != items.length - 1) {
        lines.add('\n-----');
      }
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
    final lines = <String>['Тренерский штаб DVOR 🧑‍🏫'];
    for (var index = 0; index < trainers.length; index++) {
      final trainer = trainers[index];
      lines.addAll(<String>[
        '',
        '${index + 1}. ${trainer.name}',
        '🔗 ${trainer.link}',
        '📝 ${_normalizeTrainerDescription(trainer.description)}',
      ]);
    }
    return lines.join('\n');
  }

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
    final lines = <String>[title];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.addAll(<String>[
        '',
        '• $icon ${_escapeHtml(item.title)}',
        '   🕒 Когда: ${MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo)}',
        if (item.price != null) '   💳 Взнос: ${MessageFormatters.trainingPriceLabel(item.price)}',
        if (item.description.trim().isNotEmpty)
          '   📝 Описание: ${_escapeHtml(item.description.trim())}',
      ]);
      if (index != items.length - 1) {
        lines.add('\n-----');
      }
    }
    return lines.join('\n');
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
      final value = trimmed.substring(1).trim();
      return value.isEmpty ? null : value;
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final value = trimmed.replaceFirst('@', '').trim();
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
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first.trim();
    return segment.isEmpty ? null : segment;
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
}
