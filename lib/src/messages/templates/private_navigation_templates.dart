import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';

final class PrivateNavigationTemplates {
  const PrivateNavigationTemplates();

  String privateWelcome() {
    return 'Добро пожаловать в DVOR 🤝\n\n'
        'Быстрый старт:\n'
        '1) Нажми «${MessageCopy.buttonBookTraining}» и выбери мероприятие.\n'
        '2) Оплати и отправь чек в этот чат.\n'
        '3) Следи за статусом в «${MessageCopy.buttonProfile}».\n\n'
        'Ещё здесь: запись друга, тренерский штаб и помощь.\n'
        // TODO(subscription): вернуть упоминание абонемента PRO в welcome.
        'Группа DVOR: https://t.me/+n4ksCb3kFRQ5MTcy';
  }

  String onboardingWelcome() {
    return 'Добро пожаловать в DVOR.\n\n'
        'Здесь тренировки, походы и трейлы — в одном ритме с командой.\n'
        'Сейчас не нужно разбираться во всём. Достаточно одного шага: '
        'понять, с чего тебе удобнее начать.';
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

  String onboardingClubMap({required bool starterBonusAvailable}) {
    final bonusLine = starterBonusAvailable
        ? '\n\nУ тебя есть бесплатная тренировка за старт — успей использовать.'
        : '';
    return 'Коротко, как устроен DVOR:\n'
        '• группа — афиши и движ;\n'
        '• бот — расписание, запись, оплата, бонусы;\n'
        '• поддержка — @dvor_support.\n\n'
        'Следующий шаг: выбери тренировку и запишись.'
        '$bonusLine';
  }

  String onboardingNeedHelp() {
    return 'На связи поддержка DVOR: @dvor_support\n'
        'Напиши, на каком шаге застрял — поможем.';
  }

  String onboardingNudgeQuizReminder() {
    return 'Остался один короткий шаг — ответь на пару вопросов, '
        'и покажу, с чего начать.';
  }

  String onboardingNudgePrimaryCta() {
    return 'Ближайшие слоты уже в расписании.\n'
        'Забронируй один — так проще втянуться, чем ждать идеального момента.';
  }

  String onboardingNudgeDay5Alt() {
    return 'Если привычный формат не зашёл — попробуй другой: '
        'тренировка или outdoor. Главное — выбрать слот и прийти.';
  }

  String onboardingNudgeDay7() {
    return 'Неделя прошла — давай забронируем слот.\n'
        'Если что-то мешает, напиши @dvor_support — поможем.';
  }

  String onboardingActivationSuccess() {
    return 'Первая тренировка в DVOR — есть.\n'
        'Дальше проще: вторая закрепляет ритм.\n'
        // TODO(subscription): вернуть soft-pitch PRO в activation success.
        'Если кайф в компании — зови друга по рефералке в профиле.';
  }

  String onboardingSnoozeAck() {
    return 'Ок, без давления. Когда будешь готов — «${MessageCopy.buttonBookTraining}» '
        'или «${MessageCopy.buttonTrainings}». Я рядом.';
  }

  String trainingFeedbackAsk({required String trainingTitle}) {
    return 'Как прошла тренировка «$trainingTitle»?\n'
        'Ответ анонимный — только чтобы становилось лучше.';
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
  }) {
    final lines = <String>[
      '📝 <b>Новый анонимный отзыв о тренировке</b>',
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
    return '🎁 Тебе доступна бесплатная тренировка за старт!\n\n'
        'Нажми «${MessageCopy.buttonBookTraining}», выбери тренировку '
        'и в подтверждении записи нажми «${MessageCopy.buttonUseStarterBonus}».';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
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
        '🔥 Группа DVOR: https://t.me/+n4ksCb3kFRQ5MTcy\n'
        'По остальным вопросам: @dvor_support 💬';
  }

  String dvorXFrankPromo() {
    return '🏃‍♂️ <b>15 АВГУСТА, 8:30</b> — «ДВОР БЕЖИТ В FRANK BY БАСТА»\n\n'
        '<b>Коллаборация DVORSPORT × FRANK BY BASTA</b> 🥩\n\n'
        'Бежим 5 км по Кубанской набережной.\n'
        'Беговая и силовая тренировка.\n'
        'За пультом — диджей 🎧, а после финиша мы не расходимся — '
        'бежим тусить на Мира 1.\n\n'
        '✅ <b>Важно!</b> Мероприятие полностью бесплатное.\n'
        'Записаться можно прямо сейчас через чат-бот — и ты в деле 💬\n\n'
        '🧵 Каждый участник получит фирменную наклейку-ачивку '
        'в подтверждение, что был с нами на этом забеге.\n\n'
        '☕ <b>Бонус:</b> при завтраке после тренировки кофе '
        'для любого спортсмена — бесплатно.\n\n'
        '⏰ <b>Старт:</b> 15 августа в 8:30\n'
        '📍 <b>От:</b> моста Поцелуев\n\n'
        'Ждём тебя и твоих друзей 🔥';
  }

  String dvorXFrankPromoUnavailable() {
    return 'Пока не нашли забег в актуальном расписании 🙈\n'
        'Попробуй чуть позже или запишись через «${MessageCopy.buttonBookTraining}».';
  }

  String privateFallback() {
    return 'Пока не понял сообщение 🤔\n'
        'Используй кнопки меню ниже.\n'
        'Если запутался в шаге записи, нажми «${MessageCopy.buttonMainMenu}» '
        'или «${MessageCopy.buttonHelp}».';
  }
}
