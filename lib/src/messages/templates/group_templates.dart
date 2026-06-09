final class GroupTemplates {
  const GroupTemplates({String? botUsername}) : _botUsername = botUsername;

  final String? _botUsername;

  String clubInfoPrivate() {
    return 'Добро пожаловать в спортивное объединение DVOR! 🎉\n\n'
        'Мы регулярно проводим тренировки, делимся расписанием и новостями клуба.\n'
        'Хочешь посмотреть ближайшие занятия? Отправь /trainings 👌';
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напишите боту в личку и нажмите Start 🙌'
        : 'Откройте личку с ботом: https://t.me/$botUsername и нажмите Start 🙌';
    return 'Не удалось отправить личное сообщение новому участнику 😕 $botLink';
  }

  String groupWelcome({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final mention = _groupMention(username: username, userId: userId, firstName: firstName);
    final botLink = _botDeepLink();
    final botPrompt = botLink == null
        ? '🤖 Чат с ботом: напиши боту в личку и нажми Start'
        : '🤖 Чат с ботом: <a href="$botLink">нажми, чтобы открыть</a>';
    return 'Привет, $mention! 🏃\n'
        'Ты уже в игре!\n'
        'Переходи в бота «Двор» - там твой первый шаг к победе и подарок за старт.\n'
        '$botPrompt\n'
        'Вперёд, чемпион! 🏆';
  }

  String _groupMention({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      return '@$normalizedUsername';
    }
    final normalizedName = firstName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return '<a href="tg://user?id=$userId">${_escapeHtml(normalizedName)}</a>';
    }
    return '<a href="tg://user?id=$userId">участник</a>';
  }

  String? _botDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=start';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
