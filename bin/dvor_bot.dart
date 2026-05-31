import 'dart:io';

import 'package:dvor_chatbot/src/bot/bot_runner.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/static_schedule_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:l/l.dart';

Future<void> main(List<String> args) async {
  final config = AppConfig.fromArgs(args);

  final client = TelegramClient(token: config.botToken);
  final templates = MessageTemplates();
  final scheduleRepository = const StaticScheduleRepository();

  final runner = BotRunner(
    config: config,
    client: client,
    privateHandlers: PrivateHandlers(
      sender: client,
      scheduleRepository: scheduleRepository,
      templates: templates,
    ),
    groupHandlers: GroupHandlers(
      sender: client,
      templates: templates,
      targetChatId: config.targetChatId,
      sendGroupFallback: config.sendGroupFallback,
    ),
  );

  _registerShutdown(runner);
  l.i('DVOR bot is starting...');
  await runner.start();
}

void _registerShutdown(BotRunner runner) {
  ProcessSignal.sigint.watch().listen((_) {
    l.i('SIGINT received, stopping bot...');
    runner.stop();
  });
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) {
      l.i('SIGTERM received, stopping bot...');
      runner.stop();
    });
  }
}
