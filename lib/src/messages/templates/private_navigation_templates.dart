import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:intl/intl.dart';

final class PrivateNavigationTemplates {
  const PrivateNavigationTemplates();

  String privateWelcome() {
    return 'Добро пожаловать в DVOR 🤝\n\n'
        'В боте — слоты DVOR. Дальше: выбрать, оплатить, прийти.\n\n'
        'Быстрый старт:\n'
        '1) Нажми «${MessageCopy.buttonBookTraining}» и выбери мероприятие.\n'
        '2) Оплати и отправь чек в этот чат.\n'
        '3) Следи за статусом в «${MessageCopy.buttonProfile}».\n\n'
        'Ещё здесь: запись друга, тренерский штаб и помощь.\n'
        // TODO(subscription): вернуть упоминание абонемента PRO в welcome.
        'Группа DVOR: ${MessageCopy.dvorGroupInviteUrl}';
  }

  String onboardingWelcome() {
    return 'Добро пожаловать в DVOR.\n\n'
        'Первый шаг — записаться на тренировку.\n'
        'Что сейчас важнее?';
  }

  String onboardingQuizGoal() {
    return 'Что сейчас важнее?';
  }

  String onboardingQuizExperience() {
    return 'Какой у тебя опыт?';
  }

  String onboardingTrackChoice() {
    return 'С чего начнём?';
  }

  String onboardingClubMap({
    required bool starterBonusAvailable,
    List<TrainingInfo> citySlots = const <TrainingInfo>[],
  }) {
    final bonusLine =
        starterBonusAvailable ? '\n\nУ тебя есть бесплатная тренировка за старт.' : '';
    final slotsBlock = _citySlotsBlock(citySlots);
    return 'Следующий шаг — выбрать слот и записаться.\n\n'
        'В боте — расписание и запись.\n'
        'Не с кем идти — приходи один. На площадке уже будут свои.\n'
        '$slotsBlock'
        '\nВ группе — афиши: ${MessageCopy.dvorGroupInviteUrl}\n'
        'Можно зайти и ничего не писать.'
        '$bonusLine';
  }

  String _citySlotsBlock(List<TrainingInfo> citySlots) {
    if (citySlots.isEmpty) {
      return '';
    }
    final lines = <String>['', 'Ближайшие слоты в городе:', ''];
    for (final slot in citySlots) {
      final kind = switch (_citySlotKind(slot.title)) {
        'boxing' => 'Бокс',
        'strength' => 'Силовая',
        'run' => 'Забег',
        _ => slot.title,
      };
      lines
        ..add('$kind: ${slot.title}')
        ..add('${_slotWhen(slot)} · ${slot.location}')
        ..add('');
    }
    return lines.join('\n');
  }

  String _citySlotKind(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('бокс')) {
      return 'boxing';
    }
    if (lower.contains('сил')) {
      return 'strength';
    }
    if (lower.contains('забег') || lower.contains('бег')) {
      return 'run';
    }
    return '';
  }

  String onboardingNeedHelp() {
    return 'На связи поддержка DVOR: @dvor_support\n'
        'Напиши, на каком шаге застрял — поможем.';
  }

  String onboardingNudgeQuizReminder() {
    return 'Остался один короткий шаг — ответь на пару вопросов, '
        'и покажу слоты.\n'
        'Или сразу открой запись.';
  }

  String onboardingNudgePrimaryCta({TrainingInfo? nearest}) {
    if (nearest == null) {
      return 'Ближайшие слоты уже в расписании.\n'
          'Выбери один и запишись.';
    }
    final when = _slotWhen(nearest);
    return 'Ближайший слот уже в расписании.\n\n'
        '${nearest.title}\n'
        '$when · ${nearest.location}\n\n'
        'Запишись, если подходит.';
  }

  String _slotWhen(TrainingInfo nearest) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final weekday = switch (nearest.startsAt.weekday) {
      DateTime.monday => 'пн',
      DateTime.tuesday => 'вт',
      DateTime.wednesday => 'ср',
      DateTime.thursday => 'чт',
      DateTime.friday => 'пт',
      DateTime.saturday => 'сб',
      DateTime.sunday => 'вс',
      _ => '',
    };
    final formatted = formatter.format(nearest.startsAt);
    return weekday.isEmpty ? formatted : '$weekday, $formatted';
  }

  String onboardingNudgeDay5Alt() {
    return 'Если привычный формат не зашёл — попробуй другой: '
        'тренировка или outdoor. Главное — выбрать слот и прийти.';
  }

  String onboardingNudgeDay7() {
    return 'Неделя прошла. Ближайшие слоты — в расписании.\n'
        'Если что-то мешает, напиши @dvor_support — поможем.';
  }

  String groupInviteNudge(int index) {
    return switch (index) {
      2 => 'Группа DVOR — это афиши и живой чат. Бот их не дублирует.\n\n'
          'Представляться не обязательно. Если ещё не внутри — вот вход.',
      3 => 'Бот умеет запись. Группа — новости и общение.\n\n'
          'Ссылка, если ещё не заходил. Можно просто читать.',
      _ => '<b>Новости и общение — в группе DVOR</b>\n\n'
          'В боте — расписание и запись. Афиши и чат — там.\n\n'
          'Если зайдёшь — можно ничего не писать. '
          'Кто хочет, коротко: имя и чем занимаешься.\n\n'
          'Заходи, когда будет удобно.',
    };
  }

  String onboardingActivationSuccess() {
    return 'Первая тренировка в DVOR — есть.\n'
        'Дальше проще: вторая закрепляет ритм.\n'
        // TODO(subscription): вернуть soft-pitch PRO в activation success.
        'Друга можно записать по рефералке в профиле.';
  }

  String onboardingSnoozeAck() {
    return 'Ок, без давления. Когда будет удобно — «${MessageCopy.buttonBookTraining}» '
        'или «${MessageCopy.buttonTrainings}». Я рядом.';
  }

  String trainingFeedbackAsk({
    required String trainingTitle,
    ActivityCategory category = ActivityCategory.trainings,
  }) {
    final question = switch (category) {
      ActivityCategory.hikes => 'Как прошел поход «$trainingTitle»?',
      ActivityCategory.trails => 'Как прошел трейл «$trainingTitle»?',
      ActivityCategory.trainings => 'Как прошла тренировка «$trainingTitle»?',
    };
    return '$question\nОтвет анонимный — только чтобы становилось лучше.';
  }

  String trainingFeedbackCommentAsk() {
    return 'Если хочешь — одним сообщением, что зашло или что улучшить. '
        'Можно пропустить.';
  }

  String trainingFeedbackThanks() {
    return 'Спасибо — это помогает делать DVOR лучше.';
  }

  String trainingFeedbackAdminNotification({
    required String trainingTitle,
    required String ratingLabel,
    String? comment,
    ActivityCategory category = ActivityCategory.trainings,
  }) {
    final subject = switch (category) {
      ActivityCategory.hikes => 'походе',
      ActivityCategory.trails => 'трейле',
      ActivityCategory.trainings => 'тренировке',
    };
    final lines = <String>[
      '📝 <b>Новый анонимный отзыв о $subject</b>',
      'Занятие: <b>$trainingTitle</b>',
      'Оценка: <b>$ratingLabel</b>',
    ];
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      lines
        ..add('')
        ..add('Комментарий:')
        ..add(trimmed);
    }
    return lines.join('\n');
  }

  String starterBonusOnboardingOffer() {
    return 'Тебе доступна бесплатная тренировка за старт.\n\n'
        'Нажми «${MessageCopy.buttonBookTraining}», выбери тренировку '
        'и в подтверждении записи нажми «${MessageCopy.buttonUseStarterBonus}».';
  }

  String privateHelp() {
    return 'В боте — слоты, запись и статус. Вот чем могу помочь 👇\n'
        '• Показываю ближайшие тренировки, походы и трейлы 📅\n'
        // TODO(subscription): вернуть строки про PRO-абонемент в помощи.
        '• Показываю список тренеров и контакты штаба 🧑‍🏫\n'
        '• Помогаю записаться на выбранное мероприятие ✍️\n'
        '• Напоминаю про систему лояльности: каждая 5-я тренировка бесплатная 🎁\n'
        '• Показываю профиль: твои записи, статусы и прогресс по бонусам 👤\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'Правила отмены:\n'
        '• Походы и трейлы — не позже чем за 7 дней до старта.\n'
        '• Бесплатные тренировки — можно отменить в любой момент.\n'
        '• Платные тренировки — через поддержку @dvor_support.\n\n'
        'Перенос доступен для тренировок на слот той же стоимости.\n\n'
        '🔥 Группа DVOR: ${MessageCopy.dvorGroupInviteUrl}\n'
        'По остальным вопросам: @dvor_support 💬';
  }

  String privateFallback() {
    return 'Пока не понял сообщение 🤔\n'
        'Используй кнопки меню ниже.\n'
        'Если запутался в шаге записи, нажми «${MessageCopy.buttonMainMenu}» '
        'или «${MessageCopy.buttonHelp}».';
  }
}
