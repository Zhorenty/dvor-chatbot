import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';

final class PrivateHandlers {
  const PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required MessageTemplates templates,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _templates = templates;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final MessageTemplates _templates;

  Future<bool> handle(Map<String, dynamic> message) async {
    final chat = message['chat'];
    if (chat is! Map || chat['type']?.toString() != 'private') {
      return false;
    }
    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    final text = message['text']?.toString().trim();
    if (text == null) {
      return false;
    }

    if (text.startsWith('/start')) {
      await _sender.sendMessage(chatId, _templates.privateWelcome());
      return true;
    }

    if (text.startsWith('/trainings')) {
      final upcoming = _scheduleRepository.upcoming();
      await _sender.sendMessage(chatId, _templates.trainings(upcoming));
      return true;
    }

    return false;
  }
}
