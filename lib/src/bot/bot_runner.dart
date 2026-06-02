import 'dart:async';

import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/jobs/payment_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_sync_job.dart';
import 'package:dvor_chatbot/src/jobs/welcome_cleanup_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:l/l.dart';

final class BotRunner {
  BotRunner({
    required AppConfig config,
    required TelegramClient client,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required PrivateHandlers privateHandlers,
    required GroupHandlers groupHandlers,
  })  : _config = config,
        _client = client,
        _scheduleRepository = scheduleRepository,
        _scheduleSyncJob = ScheduleSyncJob(scheduleRepository: scheduleRepository),
        _paymentReminderJob = PaymentReminderJob(
          bookingRepository: bookingRepository,
          sender: sender,
          templates: templates,
        ),
        _welcomeCleanupJob = WelcomeCleanupJob(
          onboardingRepository: onboardingRepository,
          sender: sender,
        ),
        _privateHandlers = privateHandlers,
        _groupHandlers = groupHandlers;

  final AppConfig _config;
  final TelegramClient _client;
  final TrainingScheduleRepository _scheduleRepository;
  final ScheduleSyncJob _scheduleSyncJob;
  final PaymentReminderJob _paymentReminderJob;
  final WelcomeCleanupJob _welcomeCleanupJob;
  final PrivateHandlers _privateHandlers;
  final GroupHandlers _groupHandlers;

  bool _stopping = false;
  int _offset = 0;
  Timer? _scheduleSyncTimer;
  Timer? _paymentReminderTimer;
  Timer? _welcomeCleanupTimer;

  Future<void> start() async {
    final initialRefreshOk = await _scheduleRepository.refresh(force: true);
    if (!initialRefreshOk) {
      l.w('Initial schedule refresh failed. Continuing with available cache.');
    }
    _scheduleSyncTimer = Timer.periodic(
      Duration(seconds: _config.scheduleSyncIntervalSeconds),
      (_) {
        if (_stopping) {
          return;
        }
        unawaited(_scheduleSyncJob.run());
      },
    );
    _paymentReminderTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_stopping) {
        return;
      }
      unawaited(_paymentReminderJob.run());
    });
    _welcomeCleanupTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_stopping) {
        return;
      }
      unawaited(_welcomeCleanupJob.run());
    });

    while (!_stopping) {
      try {
        final updates = await _client.getUpdates(
          offset: _offset,
          timeoutSeconds: _config.pollTimeoutSeconds,
          allowedUpdates: const {'message', 'callback_query'},
        );
        for (final update in updates) {
          if (_stopping) {
            break;
          }
          final updateId = update['update_id'];
          if (updateId is int) {
            _offset = updateId + 1;
          }
          await _handleUpdate(update);
        }
      } on TelegramApiException catch (error, stackTrace) {
        l.w('Telegram API error in polling loop: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      } on TimeoutException catch (error, stackTrace) {
        l.w('Polling timeout: $error', stackTrace);
      } on Object catch (error, stackTrace) {
        l.e('Unexpected polling error: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _handleUpdate(Map<String, dynamic> update) async {
    final privateHandled = await _privateHandlers.handle(update);
    if (privateHandled) {
      return;
    }
    final message = update['message'];
    if (message is! Map) {
      return;
    }
    final normalized = Map<String, dynamic>.from(message);
    await _groupHandlers.handle(normalized);
  }

  void stop() {
    _stopping = true;
    _scheduleSyncTimer?.cancel();
    _paymentReminderTimer?.cancel();
    _welcomeCleanupTimer?.cancel();
    _client.close();
  }
}
