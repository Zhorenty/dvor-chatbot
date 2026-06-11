import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:intl/intl.dart';

final class ScheduleTemplates {
  const ScheduleTemplates();

  String trainings(List<TrainingInfo> items) {
    return _indoorActivitiesList(
      title: 'Ближайшие тренировки DVOR 💪',
      icon: '🏋️',
      items: items,
      emptyText: 'Пока тренировок в расписании нет 😌 Скоро добавим новые даты!',
    );
  }

  String yoga(List<TrainingInfo> items) {
    final list = _indoorActivitiesList(
      title: 'Ближайшая йога DVOR 🧘',
      icon: '🧘',
      items: items,
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
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return emptyText;
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
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
          '   🧑‍🏫 ${_coachTitle(coach)}: ${_escapeHtml(coach)}',
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
      title: 'Ближайшие походы DVOR 🥾',
      icon: '🥾',
      items: items,
      emptyText: 'Пока походов в расписании нет 😌',
    );
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие трейлы DVOR 🏃',
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
