import 'dart:io';

import 'package:dvor_chatbot/src/bot/bot_runner.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/static_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/static_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:l/l.dart';

Future<void> main(List<String> args) async {
  final config = AppConfig.fromArgs(args);

  final client = TelegramClient(token: config.botToken);
  final templates = MessageTemplates();
  final scheduleRepository = _createScheduleRepository(config);
  final trainerDirectoryRepository = _createTrainerDirectoryRepository(config);
  final bookingRepository = _createBookingRepository(config);
  final onboardingRepository = _createOnboardingRepository(config);
  await bookingRepository.init();
  await onboardingRepository.init();

  final runner = BotRunner(
    config: config,
    client: client,
    scheduleRepository: scheduleRepository,
    bookingRepository: bookingRepository,
    onboardingRepository: onboardingRepository,
    sender: client,
    templates: templates,
    privateHandlers: PrivateHandlers(
      sender: client,
      scheduleRepository: scheduleRepository,
      bookingRepository: bookingRepository,
      onboardingRepository: onboardingRepository,
      trainerDirectoryRepository: trainerDirectoryRepository,
      templates: templates,
      adminUserIds: config.adminUserIds,
      adminChatId: config.adminChatId,
    ),
    groupHandlers: GroupHandlers(
      sender: client,
      onboardingRepository: onboardingRepository,
      templates: templates,
      targetChatId: config.targetChatId,
    ),
  );

  _registerShutdown(runner);
  l.i('DVOR bot is starting...');
  try {
    await runner.start();
  } finally {
    await bookingRepository.close();
    await onboardingRepository.close();
  }
}

TrainerDirectoryRepository _createTrainerDirectoryRepository(AppConfig config) {
  switch (config.scheduleSource) {
    case ScheduleSource.googleSheets:
      final rawUrl = config.googleSheetsCsvUrl;
      if (rawUrl == null || rawUrl.isEmpty) {
        throw ArgumentError(
          'GOOGLE_SHEETS_CSV_URL is required when SCHEDULE_SOURCE=google_sheets.',
        );
      }
      return GoogleSheetsTrainerDirectoryRepository(
        csvUrl: Uri.parse(rawUrl),
        minRefreshInterval: Duration(seconds: config.scheduleSyncIntervalSeconds),
      );
    case ScheduleSource.staticData:
      return const StaticTrainerDirectoryRepository();
  }
}

TrainingScheduleRepository _createScheduleRepository(AppConfig config) {
  switch (config.scheduleSource) {
    case ScheduleSource.googleSheets:
      final rawUrl = config.googleSheetsCsvUrl;
      if (rawUrl == null || rawUrl.isEmpty) {
        throw ArgumentError(
          'GOOGLE_SHEETS_CSV_URL is required when SCHEDULE_SOURCE=google_sheets.',
        );
      }
      return GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse(rawUrl),
        minRefreshInterval: Duration(seconds: config.scheduleSyncIntervalSeconds),
      );
    case ScheduleSource.staticData:
      return const StaticScheduleRepository();
  }
}

BookingRepository _createBookingRepository(AppConfig config) {
  return SqliteBookingRepository(
    dbPath: config.bookingsDbPath,
    pendingPaymentTtl: Duration(minutes: config.pendingPaymentTtlMinutes),
  );
}

OnboardingRepository _createOnboardingRepository(AppConfig config) {
  return SqliteOnboardingRepository(
    dbPath: config.bookingsDbPath,
  );
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
