import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';

final class PrivateNavigationTemplates {
  const PrivateNavigationTemplates();

  String privateWelcome() {
    return 'Добро пожаловать в DVOR 🤝\n\n'
        'Что можно сделать в боте:\n'
        '• посмотреть расписание,\n'
        '• записаться на тренировку/йогу/поход/трейл,\n'
        '• отправить подтверждение оплаты,\n'
        '• открыть профиль и управлять своими записями.\n\n'
        '🔥 Хочешь быть в движухе DVOR каждый день?\n'
        'В нашей группе публикуем афиши всех мероприятий, общаемся, делимся новостями и анонсами:\n'
        'https://t.me/+n4ksCb3kFRQ5MTcy\n\n'
        'Быстрый старт:\n'
        '1) Нажми «${MessageCopy.buttonTrainings}» и выбери категорию.\n'
        '2) Нажми «${MessageCopy.buttonBookTraining}» и выбери событие.\n'
        '3) После оплаты нажми «${MessageCopy.buttonSubmitPayment}» и отправь файл чека.\n\n'
        'Если нужна подсказка, нажми «${MessageCopy.buttonHelp}».';
  }

  String starterBonusOnboardingOffer() {
    return '🎁 Тебе доступна бесплатная тренировка за старт!\n\n'
        'Нажми «${MessageCopy.buttonBookTraining}», выбери тренировку и в подтверждении записи '
        'используй кнопку «${MessageCopy.buttonUseStarterBonus}».';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
        '• Показываю ближайшие тренировки, йогу, походы и трейлы 📅\n'
        '• Показываю список тренеров и контакты штаба 🧑‍🏫\n'
        '• Помогаю записаться на выбранное мероприятие ✍️\n'
        '• Напоминаю про систему лояльности: каждая 5-я тренировка бесплатная 🎁\n'
        '• Показываю профиль: твои записи, статусы и прогресс по бонусам 👤\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        '🔥 Вступай в группу DVOR: там публикуем афиши всех мероприятий, общаемся и делимся новостями:\n'
        'https://t.me/+n4ksCb3kFRQ5MTcy\n\n'
        'По остальным вопросам пиши в поддержку: @dvor_support 💬\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /profile, /my_bookings, /coaches.';
  }

  String privateFallback() {
    return 'Пока не понял сообщение 🤔\n'
        'Используй кнопки меню ниже.\n'
        'Если запутался в шаге записи, нажми «${MessageCopy.buttonMainMenu}» '
        'или «${MessageCopy.buttonHelp}».';
  }
}
