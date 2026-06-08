import 'dart:async';

import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/jobs/payment_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_sync_job.dart';
import 'package:dvor_chatbot/src/jobs/starter_bonus_reminder_job.dart';
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
        _starterBonusReminderJob = StarterBonusReminderJob(
          onboardingRepository: onboardingRepository,
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
  final StarterBonusReminderJob _starterBonusReminderJob;
  final WelcomeCleanupJob _welcomeCleanupJob;
  final PrivateHandlers _privateHandlers;
  final GroupHandlers _groupHandlers;

  bool _stopping = false;
  int _offset = 0;
  bool _clientClosed = false;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;
  Timer? _scheduleSyncTimer;
  Timer? _paymentReminderTimer;
  Timer? _starterBonusReminderTimer;
  Timer? _welcomeCleanupTimer;

  Future<void> start() async {
    await _initializeLongPolling();
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
        _launchBackgroundJob('schedule sync', _scheduleSyncJob.run);
      },
    );
    _paymentReminderTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('payment reminder', _paymentReminderJob.run);
    });
    _starterBonusReminderTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('starter bonus reminder', _starterBonusReminderJob.run);
    });
    _welcomeCleanupTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('welcome cleanup', _welcomeCleanupJob.run);
    });

    while (!_stopping) {
      try {
        final updates = await _client.getUpdates(
          offset: _offset,
          timeoutSeconds: _config.pollTimeoutSeconds,
          allowedUpdates: const {'message', 'callback_query', 'chat_member'},
        );
        for (final update in updates) {
          if (_stopping) {
            break;
          }
          final updateId = update['update_id'];
          try {
            await _runTracked(() => _handleUpdate(update));
            if (updateId is int) {
              _offset = updateId + 1;
            }
          } on Object catch (error, stackTrace) {
            l.e('Failed to handle update (update_id=$updateId): $error', stackTrace);
          }
        }
      } on TelegramApiException catch (error, stackTrace) {
        if (error.statusCode == 409) {
          l.e(
            'Polling conflict (409): another bot instance is likely running. Stopping current instance.',
            stackTrace,
          );
          _stopping = true;
          break;
        }
        l.w('Telegram API error in polling loop: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      } on TimeoutException catch (error, stackTrace) {
        l.w('Polling timeout: $error', stackTrace);
      } on Object catch (error, stackTrace) {
        l.e('Unexpected polling error: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    await _waitForIdleOperations();
    _closeClient();
  }

  Future<void> _handleUpdate(Map<String, dynamic> update) async {
    final privateHandled = await _privateHandlers.handle(update);
    if (privateHandled) {
      return;
    }
    await _groupHandlers.handleUpdate(update);
  }

  Future<void> stop() async {
    if (_stopping) {
      return;
    }
    _stopping = true;
    _scheduleSyncTimer?.cancel();
    _paymentReminderTimer?.cancel();
    _starterBonusReminderTimer?.cancel();
    _welcomeCleanupTimer?.cancel();
    _closeClient();
    await _waitForIdleOperations();
  }

  Future<void> _initializeLongPolling() async {
    try {
      await _client.deleteWebhook();
    } on Object catch (error, stackTrace) {
      l.w('Failed to reset Telegram webhook before polling: $error', stackTrace);
    }
  }

  Future<T> _runTracked<T>(Future<T> Function() action) async {
    _activeOperations += 1;
    try {
      return await action();
    } finally {
      _activeOperations -= 1;
      if (_activeOperations == 0) {
        _idleCompleter?.complete();
        _idleCompleter = null;
      }
    }
  }

  void _launchBackgroundJob(String name, Future<void> Function() action) {
    unawaited(
      _runTracked(action).onError<Object>((error, stackTrace) {
        l.w('Background $name job failed: $error', stackTrace);
      }),
    );
  }

  Future<void> _waitForIdleOperations() async {
    if (_activeOperations == 0) {
      return;
    }
    final completer = _idleCompleter ??= Completer<void>();
    await completer.future;
  }

  void _closeClient() {
    if (_clientClosed) {
      return;
    }
    _clientClosed = true;
    _client.close();
  }
}
