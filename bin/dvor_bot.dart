import 'dart:async';
import 'dart:io';

import 'package:dvor_chatbot/src/bot/bot_runner.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_subscription_repository.dart';
import 'package:dvor_chatbot/src/data/static_promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/static_schedule_repository.dart';
import 'package:dvor_chatbot/src/data/static_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
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
      final promoCodeRepository = _createPromoCodeRepository(config);
      final bookingRepository = _createBookingRepository(config);
      final subscriptionRepository = _createSubscriptionRepository(config);
      final onboardingRepository = _createOnboardingRepository(config);
      await bookingRepository.init();
      await subscriptionRepository.init();
      await onboardingRepository.init();

      final runner = BotRunner(
        config: config,
        client: client,
        scheduleRepository: scheduleRepository,
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        subscriptionRepository: subscriptionRepository,
        sender: client,
        templates: templates,
        privateHandlers: PrivateHandlers(
          sender: client,
          scheduleRepository: scheduleRepository,
          bookingRepository: bookingRepository,
          subscriptionRepository: subscriptionRepository,
          onboardingRepository: onboardingRepository,
          trainerDirectoryRepository: trainerDirectoryRepository,
          promoCodeRepository: promoCodeRepository,
          templates: templates,
          adminUserIds: config.adminUserIds,
          adminChatId: config.adminChatId,
          targetChatId: config.targetChatId,
        ),
        groupHandlers: GroupHandlers(
          sender: client,
          onboardingRepository: onboardingRepository,
          templates: templates,
          targetChatId: config.targetChatId,
        ),
      );

      _registerShutdown(runner);
      l.i(
        'DVOR bot is starting... '
        'scheduleSource=${config.scheduleSource.name}, '
        'targetChatId=${config.targetChatId}, '
        'admins=${config.adminUserIds.length}, '
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

SubscriptionRepository _createSubscriptionRepository(AppConfig config) {
  return SqliteSubscriptionRepository(
    dbPath: config.bookingsDbPath,
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
