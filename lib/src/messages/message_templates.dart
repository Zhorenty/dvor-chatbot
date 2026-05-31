import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates();

  String privateWelcome() {
    return 'Привет! Я бот спортивного объединения DVOR.\n\n'
        'Команды:\n'
        '/trainings — ближайшие тренировки';
  }

  String trainings(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'Пока нет запланированных тренировок. Скоро добавим новые даты.';
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Ближайшие тренировки DVOR:'];
    for (final item in items) {
      final coach = item.coach == null ? '' : '\nТренер: ${item.coach}';
      final notes = item.notes == null ? '' : '\nПримечание: ${item.notes}';
      lines.add(
        '\n• ${item.title}\n'
        'Когда: ${formatter.format(item.startsAt)}\n'
        'Где: ${item.location}$coach$notes',
      );
    }
    return lines.join('\n');
  }

  String clubInfoPrivate() {
    return 'Добро пожаловать в спортивное объединение DVOR!\n\n'
        'Здесь мы регулярно проводим тренировки, делимся расписанием и новостями клуба.\n'
        'Чтобы посмотреть ближайшие тренировки, отправьте команду /trainings.';
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напишите боту в личку и нажмите Start.'
        : 'Откройте личку с ботом: https://t.me/$botUsername и нажмите Start.';
    return 'Не получилось отправить личное сообщение новому участнику. $botLink';
  }
}
