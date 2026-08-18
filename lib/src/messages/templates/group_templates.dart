import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:intl/intl.dart';

final class GroupTemplates {
  const GroupTemplates({String? botUsername}) : _botUsername = botUsername;

  final String? _botUsername;

  String clubInfoPrivate() {
    return 'Добро пожаловать в DVOR 🤝\n\n'
        'В боте можно посмотреть расписание, записаться на мероприятия '
        'и получить подарок за старт.\n'
        'Нажми /start или «Записаться», чтобы начать 👌';
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напиши боту в личку и нажми Start 🙌'
        : 'Открой личку с ботом: https://t.me/$botUsername и нажми Start 🙌';
    return 'Не удалось отправить личное сообщение новому участнику 😕 $botLink';
  }

  String groupWelcome({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final mention = _groupMention(username: username, userId: userId, firstName: firstName);
    final botLink = _botStartDeepLink();
    final botPrompt = botLink == null
        ? '🤖 Чат с ботом: напиши боту в личку и нажми Start'
        : '🤖 Чат с ботом: <a href="$botLink">нажми, чтобы открыть — там первый шаг и подарок за старт</a>';
    return 'Привет, $mention! 🏃\n'
        'Добро пожаловать в DVOR.\n'
        'В боте — расписание, запись на мероприятия и подарок за старт.\n'
        '$botPrompt\n'
        'Вперёд! 🏆';
  }

  String groupScheduleBroadcast({
    required List<TrainingInfo> trainings,
    required int weekday,
  }) {
    final headline = switch (weekday) {
      DateTime.sunday => 'Новая неделя DVOR уже в расписании 🔥',
      DateTime.tuesday => 'Середина недели — самое время записаться 💪',
      DateTime.thursday => 'Не упусти тренировки до выходных ⚡',
      _ => 'Расписание DVOR — успей записаться 🔥',
    };
    final lead = switch (weekday) {
      DateTime.sunday =>
        'Свежий план на ближайшие дни уже здесь. Бег, сила, бокс, утренние забеги — '
            'выбирай свой темп и компанию.',
      DateTime.tuesday => 'Неделя в разгаре, а места на тренировки разбирают быстро. '
          'Загляни в расписание и закрепи слот за собой.',
      DateTime.thursday => 'До выходных осталось чуть-чуть: успей записаться на ближайшие занятия '
          'и зарядиться перед уикендом.',
      _ => 'Ближайшие тренировки уже в календаре. Выбирай формат и приходи в команду DVOR.',
    };
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      '📅 <b>$headline</b>',
      '',
      lead,
      '',
      '<b>Что будет:</b>',
    ];
    for (var index = 0; index < trainings.length; index++) {
      final training = trainings[index];
      final coach = training.coach?.trim();
      final weekdayShort = _weekdayShort(training.startsAt.weekday);
      final dateLabel = weekdayShort.isEmpty
          ? formatter.format(training.startsAt)
          : '$weekdayShort, ${formatter.format(training.startsAt)}';
      lines.addAll(<String>[
        '',
        '<b>${index + 1}. ${_escapeHtml(training.title)}</b>',
        '🕒 $dateLabel',
        '📍 ${_escapeHtml(training.location)}',
        if (training.price != null) '💳 ${MessageFormatters.trainingPriceLabel(training.price)}',
        if (coach != null && coach.isNotEmpty) '🧑‍🏫 ${_escapeHtml(coach)}',
      ]);
    }
    lines.addAll(<String>[
      '',
      'Запись в пару тапов в боте — места разлетаются быстро 👇',
      _groupBookingCta(),
    ]);
    return lines.join('\n');
  }

  String groupReferralBroadcast() {
    return '🎁 <b>Приведи друга — получи тренировку бесплатно</b>\n\n'
        'В DVOR кайфовее в компании. А еще это выгодно:\n'
        '1) Открой бота → <b>Профиль</b> → <b>Реферальная программа</b>\n'
        '2) Отправь другу свою персональную ссылку\n'
        '3) Когда друг пройдет <b>первую платную тренировку</b> — '
        'тебе начислится <b>1 бесплатная</b>\n\n'
        'Собирай свою команду и тренируйтесь вместе 💪\n'
        '${_groupBookingCta()}';
  }

  String _groupMention({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final normalizedName = firstName?.trim();
    final hasName = normalizedName != null && normalizedName.isNotEmpty;
    final displayName = hasName ? _escapeHtml(normalizedName) : 'участник';

    final normalizedUsername = username?.trim();
    final handle = normalizedUsername == null || normalizedUsername.isEmpty
        ? null
        : (normalizedUsername.startsWith('@')
            ? normalizedUsername.substring(1)
            : normalizedUsername);
    if (handle != null && handle.isNotEmpty) {
      if (hasName) {
        return '<a href="https://t.me/${_escapeHtml(handle)}">$displayName</a>';
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
      return 'Открыть бота: $deepLink';
    }
    return 'Чтобы записаться, открой бота в личке и нажми /start.';
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

  String _escapeHtml(String value) => escapeHtml(value);
}
