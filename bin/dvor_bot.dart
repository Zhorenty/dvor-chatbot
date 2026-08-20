import 'dart:async';
import 'dart:io';

import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/application/schedule_catalog_service.dart';
import 'package:dvor_chatbot/src/bot/bot_runner.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/dvor_team_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_api_writer.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dvor_team_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_subscription_repository.dart';
import 'package:dvor_chatbot/src/data/static_promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/static_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/static_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/logging_message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:l/l.dart';

void main(List<String> args) {
  runZonedGuarded(
    () async {
      final config = AppConfig.fromArgs(args);

      final client = TelegramClient(token: config.botToken);
      String? botUsername;
      try {
        botUsername = await client.getBotUsername();
      } on Object catch (error, stackTrace) {
        l.w('Failed to resolve bot username: $error', stackTrace);
      }
      final templates = MessageTemplates(botUsername: botUsername);
      final scheduleRepository = _createScheduleRepository(config);
      final trainerDirectoryRepository = _createTrainerDirectoryRepository(config);
      final dvorTeamRepository = _createDvorTeamRepository(config);
      final promoCodeRepository = _createPromoCodeRepository(config);
      final databaseHandle = SqliteDatabaseHandle.open(config.bookingsDbPath);
      final jobDedupeRepository = JobDedupeRepository(databaseHandle: databaseHandle)..initSchema();
      final bookingRepository = SqliteBookingRepository(
        databaseHandle: databaseHandle,
        pendingPaymentTtl: Duration(minutes: config.pendingPaymentTtlMinutes),
      );
      final subscriptionRepository = SqliteSubscriptionRepository(
        databaseHandle: databaseHandle,
      );
      final onboardingRepository = SqliteOnboardingRepository(
        databaseHandle: databaseHandle,
      );
      final conversationLogRepository = SqliteConversationLogRepository(
        databaseHandle: databaseHandle,
      );
      await bookingRepository.init();
      await subscriptionRepository.init();
      await onboardingRepository.init();
      await conversationLogRepository.init();

      GoogleSheetsWriter? googleSheetsWriter;
      if (config.googleSheetsWriteEnabled) {
        try {
          googleSheetsWriter = await GoogleSheetsApiWriter.connectFromConfig(config);
          l.i(
            'Google Sheets write enabled. '
            'spreadsheetId=${config.googleSheetsSpreadsheetId}, '
            'sheet=${config.googleSheetsWriteSheetTitle}, '
            'intervalSeconds=${config.googleSheetsWriteIntervalSeconds}',
          );
        } on Object catch (error, stackTrace) {
          l.e('Failed to enable Google Sheets write: $error', stackTrace);
        }
      }

      final catalogRepository = _createScheduleCatalogRepository(
        config: config,
        googleSheetsWriter: googleSheetsWriter,
      );
      final scheduleCatalogService = ScheduleCatalogService(
        catalogRepository: catalogRepository,
        scheduleRepository: scheduleRepository,
        timezoneOffsetHours: config.timezoneOffsetHours,
      );
      final sender = LoggingMessageSender(
        inner: client,
        conversationLog: conversationLogRepository,
      );
      final groupAnnouncements = GroupAnnouncementService(sender: sender);
      final runner = BotRunner(
        config: config,
        client: client,
        scheduleRepository: scheduleRepository,
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        subscriptionRepository: subscriptionRepository,
        sender: sender,
        templates: templates,
        groupAnnouncements: groupAnnouncements,
        jobDedupeRepository: jobDedupeRepository,
        privateHandlers: PrivateHandlers(
          sender: sender,
          scheduleRepository: scheduleRepository,
          bookingRepository: bookingRepository,
          subscriptionRepository: subscriptionRepository,
          onboardingRepository: onboardingRepository,
          conversationLogRepository: conversationLogRepository,
          trainerDirectoryRepository: trainerDirectoryRepository,
          dvorTeamRepository: dvorTeamRepository,
          promoCodeRepository: promoCodeRepository,
          templates: templates,
          adminUserIds: config.adminUserIds,
          adminChatId: config.adminChatId,
          targetChatId: config.targetChatId,
          groupAnnouncements: groupAnnouncements,
          onboardingDripEnabled: config.onboardingDripEnabled,
          scheduleCatalogService: scheduleCatalogService,
          timezoneOffsetHours: config.timezoneOffsetHours,
        ),
        groupHandlers: GroupHandlers(
          sender: sender,
          onboardingRepository: onboardingRepository,
          templates: templates,
          targetChatId: config.targetChatId,
          adminUserIds: config.adminUserIds,
          adminChatId: config.adminChatId,
          antiSpamEnabled: config.antiSpamEnabled,
        ),
        googleSheetsWriter: googleSheetsWriter,
        scheduleCatalogService: scheduleCatalogService,
        conversationLogRepository: conversationLogRepository,
      );

      _registerShutdown(runner);
      l.i(
        'DVOR bot is starting... '
        'scheduleSource=${config.scheduleSource.name}, '
        'targetChatId=${config.targetChatId}, '
        'admins=${config.adminUserIds.length}, '
        'antiSpam=${config.antiSpamEnabled}, '
        'pendingPaymentTtlMinutes=${config.pendingPaymentTtlMinutes}, '
        'logLevel=${config.logLevel}',
      );
      try {
        await runner.start();
      } finally {
        await runner.stop();
        await bookingRepository.close();
        await subscriptionRepository.close();
        await onboardingRepository.close();
        await conversationLogRepository.close();
        databaseHandle.close();
      }

      final code = runner.exitCode;
      if (code != 0) {
        exit(code);
      }
    },
    (error, stackTrace) {
      l.e('Unhandled async error: $error', stackTrace);
    },
  );
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

DvorTeamRepository _createDvorTeamRepository(AppConfig config) {
  switch (config.scheduleSource) {
    case ScheduleSource.googleSheets:
      final rawUrl = config.googleSheetsCsvUrl;
      if (rawUrl == null || rawUrl.isEmpty) {
        throw ArgumentError(
          'GOOGLE_SHEETS_CSV_URL is required when SCHEDULE_SOURCE=google_sheets.',
        );
      }
      return GoogleSheetsDvorTeamRepository(
        csvUrl: Uri.parse(rawUrl),
        minRefreshInterval: Duration(seconds: config.scheduleSyncIntervalSeconds),
      );
    case ScheduleSource.staticData:
      return const StaticDvorTeamRepository();
  }
}

PromoCodeRepository _createPromoCodeRepository(AppConfig config) {
  switch (config.scheduleSource) {
    case ScheduleSource.googleSheets:
      final rawUrl = config.googleSheetsCsvUrl;
      if (rawUrl == null || rawUrl.isEmpty) {
        throw ArgumentError(
          'GOOGLE_SHEETS_CSV_URL is required when SCHEDULE_SOURCE=google_sheets.',
        );
      }
      return GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse(rawUrl),
        minRefreshInterval: Duration(seconds: config.scheduleSyncIntervalSeconds),
      );
    case ScheduleSource.staticData:
      return const StaticPromoCodeRepository();
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

ScheduleCatalogRepository _createScheduleCatalogRepository({
  required AppConfig config,
  required GoogleSheetsWriter? googleSheetsWriter,
}) {
  if (config.scheduleSource != ScheduleSource.googleSheets) {
    return const NoopScheduleCatalogRepository();
  }
  if (googleSheetsWriter is GoogleSheetsApiWriter) {
    return GoogleSheetsScheduleCatalogRepository(gateway: googleSheetsWriter.gateway);
  }
  return const NoopScheduleCatalogRepository(
    availability: ScheduleCatalogAvailability.writeDisabled,
  );
}

void _registerShutdown(BotRunner runner) {
  ProcessSignal.sigint.watch().listen(
    (_) {
      l.i('SIGINT received, stopping bot...');
      runner.stop().catchError((Object error, StackTrace stackTrace) {
        l.e('Error while stopping on SIGINT: $error', stackTrace);
      });
    },
    onError: (Object error, StackTrace stackTrace) {
      l.e('Error in SIGINT signal stream: $error', stackTrace);
    },
  );
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(
      (_) {
        l.i('SIGTERM received, stopping bot...');
        runner.stop().catchError((Object error, StackTrace stackTrace) {
          l.e('Error while stopping on SIGTERM: $error', stackTrace);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        l.e('Error in SIGTERM signal stream: $error', stackTrace);
      },
    );
  }
}
