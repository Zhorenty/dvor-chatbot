import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/rich_html.dart';
import 'package:intl/intl.dart';

final class GroupTemplates {
  const GroupTemplates({String? botUsername}) : _botUsername = botUsername;

  final String? _botUsername;

  String clubInfoPrivate() {
    return RichHtml.screen(
      title: 'DVOR',
      lead: 'В боте — слоты: расписание, запись и подарок за старт.',
    );
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напишите боту в личку и нажмите Start.'
        : 'Откройте личку с ботом: https://t.me/$botUsername и нажмите Start.';
    return RichHtml.screen(
      title: 'Личка закрыта',
      lead: 'Не получилось написать в личку. Это нормально.',
      paragraphs: <String>[botLink],
    );
  }

  String groupWelcome({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final mention = _groupMention(username: username, userId: userId, firstName: firstName);
    final botLink = _botStartDeepLink();
    final botLine = botLink == null
        ? RichHtml.paragraph(
            'В боте — расписание, запись и подарок за старт. Напишите боту в личку и нажмите Start.')
        : RichHtml.paragraph(
            'В боте — расписание, запись и подарок за старт. '
            '<a href="${escapeHtml(botLink)}">Открыть бота</a>',
            alreadyEscaped: true,
          );
    return '<h2>Привет, $mention!</h2>'
        '${RichHtml.paragraph('Добро пожаловать в DVOR.')}'
        '$botLine';
  }

  String groupScheduleBroadcast({
    required List<TrainingInfo> trainings,
    required int weekday,
  }) {
    final headline = switch (weekday) {
      DateTime.sunday => 'Новая неделя DVOR уже в расписании',
      DateTime.tuesday => 'Середина недели',
      DateTime.thursday => 'Слоты до выходных уже в расписании',
      _ => 'Расписание DVOR',
    };
    final lead = switch (weekday) {
      DateTime.sunday => 'План на ближайшие дни уже здесь.',
      DateTime.tuesday => 'Места на тренировки разбирают быстро. Запись в боте.',
      DateTime.thursday => 'До выходных осталось чуть-чуть. Запись в боте.',
      _ => 'Ближайшие тренировки уже в календаре.',
    };
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final rows = <(String, String)>[];
    for (final training in trainings) {
      final coach = training.coach?.trim();
      final weekdayShort = _weekdayShort(training.startsAt.weekday);
      final dateLabel = weekdayShort.isEmpty
          ? formatter.format(training.startsAt)
          : '$weekdayShort, ${formatter.format(training.startsAt)}';
      final bits = <String>[
        dateLabel,
        training.location,
        if (training.price != null) MessageFormatters.trainingPriceLabel(training.price),
        if (coach != null && coach.isNotEmpty) coach,
      ];
      rows.add((training.title, bits.join(' · ')));
    }
    final buffer = StringBuffer()
      ..write(RichHtml.heading(headline))
      ..write(RichHtml.paragraph(lead))
      ..write(RichHtml.table(rows))
      ..write(RichHtml.paragraph('Запись в пару тапов в боте.'))
      ..write(RichHtml.paragraph(_groupBookingCta(), alreadyEscaped: true));
    return buffer.toString();
  }

  String groupReferralBroadcast() {
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Приведи друга — 1000 ⛰️'))
      ..write(
        RichHtml.bullets(
          <String>[
            'Откройте бота → Профиль → Реферальная программа',
            'Отправьте другу свою ссылку',
            'Друг прошёл первую платную тренировку — вам 1000 ⛰️',
          ],
        ),
      )
      ..write(RichHtml.paragraph(_groupBookingCta(), alreadyEscaped: true));
    return buffer.toString();
  }

  String _groupMention({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final normalizedName = firstName?.trim();
    final hasName = normalizedName != null && normalizedName.isNotEmpty;
    final displayName = hasName ? escapeHtml(normalizedName) : 'участник';

    final normalizedUsername = username?.trim();
    final handle = normalizedUsername == null || normalizedUsername.isEmpty
        ? null
        : (normalizedUsername.startsWith('@')
            ? normalizedUsername.substring(1)
            : normalizedUsername);
    if (handle != null && handle.isNotEmpty) {
      if (hasName) {
        return '<a href="https://t.me/${escapeHtml(handle)}">$displayName</a>';
      }
      return '@$handle';
    }
    return '<a href="tg://user?id=$userId">$displayName</a>';
  }

  String? _botStartDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=start';
  }

  String? _botBookDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=book';
  }

  String _groupBookingCta() {
    final deepLink = _botBookDeepLink();
    if (deepLink != null) {
      return 'Открыть бота: <a href="${escapeHtml(deepLink)}">${escapeHtml(deepLink)}</a>';
    }
    return 'Чтобы записаться, откройте бота в личке и нажмите /start.';
  }

  String _weekdayShort(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'пн',
      DateTime.tuesday => 'вт',
      DateTime.wednesday => 'ср',
      DateTime.thursday => 'чт',
      DateTime.friday => 'пт',
      DateTime.saturday => 'сб',
      DateTime.sunday => 'вс',
      _ => '',
    };
  }
}
