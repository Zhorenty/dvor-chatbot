import 'dart:async';

import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/jobs/economic_summary_job.dart';
import 'package:dvor_chatbot/src/jobs/payment_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/referral_broadcast_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_broadcast_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_sync_job.dart';
import 'package:dvor_chatbot/src/jobs/starter_bonus_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/subscription_renewal_job.dart';
import 'package:dvor_chatbot/src/jobs/training_day_promo_job.dart';
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
    required SubscriptionRepository subscriptionRepository,
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
          bookingPolicyService: BookingPolicyService(
            catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
          ),
          sender: sender,
          templates: templates,
          pendingPaymentTtl: Duration(minutes: config.pendingPaymentTtlMinutes),
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
        _subscriptionRenewalJob = SubscriptionRenewalJob(
          subscriptionRepository: subscriptionRepository,
          sender: sender,
          templates: templates,
        ),
        _trainingDayPromoJob = TrainingDayPromoJob(
          scheduleRepository: scheduleRepository,
          sender: sender,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
        ),
        _scheduleBroadcastJob = ScheduleBroadcastJob(
          scheduleRepository: scheduleRepository,
          sender: sender,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
        ),
        _referralBroadcastJob = ReferralBroadcastJob(
          sender: sender,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
        ),
        _economicSummaryJob = EconomicSummaryJob(
          bookingRepository: bookingRepository,
          economicSummaryService: EconomicSummaryService(
            bookingRepository: bookingRepository,
            catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
          ),
          sender: sender,
          templates: templates,
          adminChatId: config.adminChatId,
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
  final SubscriptionRenewalJob _subscriptionRenewalJob;
  final TrainingDayPromoJob _trainingDayPromoJob;
  final ScheduleBroadcastJob _scheduleBroadcastJob;
  final ReferralBroadcastJob _referralBroadcastJob;
  final EconomicSummaryJob _economicSummaryJob;
  final PrivateHandlers _privateHandlers;
  final GroupHandlers _groupHandlers;

  static const int _maxConflictRetries = 3;

  bool _stopping = false;
  int _exitCode = 0;
  int _conflictRetries = 0;
  int _offset = 0;
  bool _clientClosed = false;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;
  Timer? _scheduleSyncTimer;
  Timer? _paymentReminderTimer;
  Timer? _starterBonusReminderTimer;
  Timer? _welcomeCleanupTimer;
  Timer? _economicSummaryTimer;
  Timer? _subscriptionRenewalTimer;
  Timer? _trainingDayPromoTimer;
  Timer? _scheduleBroadcastTimer;
  Timer? _referralBroadcastTimer;

  int get exitCode => _exitCode;

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
    _economicSummaryTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('economic summary', _economicSummaryJob.run);
    });
    _subscriptionRenewalTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('subscription renewal', _subscriptionRenewalJob.run);
    });
    _trainingDayPromoTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('training day promo', _trainingDayPromoJob.run);
    });
    _scheduleBroadcastTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('schedule broadcast', _scheduleBroadcastJob.run);
    });
    _referralBroadcastTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_stopping) {
        return;
      }
      _launchBackgroundJob('referral broadcast', _referralBroadcastJob.run);
    });
    _launchBackgroundJob('economic summary', _economicSummaryJob.run);
    _launchBackgroundJob('subscription renewal', _subscriptionRenewalJob.run);
    _launchBackgroundJob('training day promo', _trainingDayPromoJob.run);
    _launchBackgroundJob('schedule broadcast', _scheduleBroadcastJob.run);
    _launchBackgroundJob('referral broadcast', _referralBroadcastJob.run);

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
          } on Object catch (error, stackTrace) {
            l.e('Failed to handle update (update_id=$updateId): $error', stackTrace);
          } finally {
            if (updateId is int) {
              _offset = updateId + 1;
            }
          }
        }
      } on TelegramApiException catch (error, stackTrace) {
        if (error.statusCode == 409) {
          _conflictRetries += 1;
          if (_conflictRetries > _maxConflictRetries) {
            l.e(
              'Polling conflict (409) persists after $_maxConflictRetries retries. '
              'Stopping with error exit so the process can be restarted.',
              stackTrace,
            );
            _exitCode = 1;
            _stopping = true;
            break;
          }
          final delaySeconds = _conflictRetries * 15;
          l.w(
            'Polling conflict (409): another instance may be running. '
            'Retry $_conflictRetries/$_maxConflictRetries in ${delaySeconds}s.',
            stackTrace,
          );
          await Future<void>.delayed(Duration(seconds: delaySeconds));
          continue;
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
    _economicSummaryTimer?.cancel();
    _subscriptionRenewalTimer?.cancel();
    _trainingDayPromoTimer?.cancel();
    _scheduleBroadcastTimer?.cancel();
    _referralBroadcastTimer?.cancel();
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
    const timeout = Duration(seconds: 15);
    final completer = _idleCompleter ??= Completer<void>();
    await completer.future.timeout(
      timeout,
      onTimeout: () {
        l.w(
          'Timed out after ${timeout.inSeconds}s waiting for '
          '$_activeOperations active operation(s); proceeding with shutdown.',
        );
      },
    );
  }

  void _closeClient() {
    if (_clientClosed) {
      return;
    }
    _clientClosed = true;
    _client.close();
  }
}
