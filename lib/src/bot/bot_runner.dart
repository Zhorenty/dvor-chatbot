import 'dart:async';

import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/admin_analytics_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/application/group_membership_lookup.dart';
import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/application/onboarding_service.dart';
import 'package:dvor_chatbot/src/application/schedule_catalog_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/jobs/economic_summary_job.dart';
import 'package:dvor_chatbot/src/jobs/google_sheets_funnel_export_job.dart';
import 'package:dvor_chatbot/src/jobs/group_invite_nudge_job.dart';
import 'package:dvor_chatbot/src/jobs/job_scheduler.dart';
import 'package:dvor_chatbot/src/jobs/onboarding_nudge_job.dart';
import 'package:dvor_chatbot/src/jobs/payment_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/referral_broadcast_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_broadcast_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_retention_job.dart';
import 'package:dvor_chatbot/src/jobs/schedule_sync_job.dart';
import 'package:dvor_chatbot/src/jobs/starter_bonus_reminder_job.dart';
import 'package:dvor_chatbot/src/jobs/subscription_renewal_job.dart';
import 'package:dvor_chatbot/src/jobs/training_day_promo_job.dart';
import 'package:dvor_chatbot/src/jobs/training_feedback_job.dart';
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
    required GroupAnnouncementService groupAnnouncements,
    required PrivateHandlers privateHandlers,
    required GroupHandlers groupHandlers,
    JobDedupeRepository? jobDedupeRepository,
    GoogleSheetsWriter? googleSheetsWriter,
    ScheduleCatalogService? scheduleCatalogService,
    ConversationLogRepository conversationLogRepository = const NoopConversationLogRepository(),
  })  : _config = config,
        _client = client,
        _scheduleRepository = scheduleRepository,
        _jobScheduler = JobScheduler(),
        _scheduleSyncJob = ScheduleSyncJob(scheduleRepository: scheduleRepository),
        _scheduleRetentionJob = ScheduleRetentionJob(
          catalogService: scheduleCatalogService ??
              ScheduleCatalogService(
                catalogRepository: const NoopScheduleCatalogRepository(),
                scheduleRepository: scheduleRepository,
                timezoneOffsetHours: config.timezoneOffsetHours,
              ),
          scheduleRepository: scheduleRepository,
        ),
        _paymentReminderJob = PaymentReminderJob(
          bookingRepository: bookingRepository,
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
          announcements: groupAnnouncements,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
          jobDedupeRepository: jobDedupeRepository,
        ),
        _scheduleBroadcastJob = ScheduleBroadcastJob(
          scheduleRepository: scheduleRepository,
          announcements: groupAnnouncements,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
          jobDedupeRepository: jobDedupeRepository,
        ),
        _referralBroadcastJob = ReferralBroadcastJob(
          announcements: groupAnnouncements,
          templates: templates,
          targetChatId: config.targetChatId,
          timezoneOffsetHours: config.timezoneOffsetHours,
          jobDedupeRepository: jobDedupeRepository,
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
        _onboardingNudgeJob = OnboardingNudgeJob(
          onboardingRepository: onboardingRepository,
          onboardingService: OnboardingService(
            onboardingRepository: onboardingRepository,
            dripEnabled: config.onboardingDripEnabled,
          ),
          sender: sender,
          templates: templates,
        ),
        _groupInviteNudgeJob = GroupInviteNudgeJob(
          onboardingRepository: onboardingRepository,
          membershipLookup: TelegramGroupMembershipLookup(client),
          sender: sender,
          templates: templates,
          targetChatId: config.targetChatId,
          enabled: config.groupInviteNudgeEnabled,
          adminUserIds: config.adminUserIds,
        ),
        _trainingFeedbackJob = TrainingFeedbackJob(
          bookingRepository: bookingRepository,
          onboardingRepository: onboardingRepository,
          sender: sender,
          templates: templates,
          enabled: config.trainingFeedbackEnabled,
          catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
          timezoneOffsetHours: config.timezoneOffsetHours,
          onAskFeedback: ({
            required int userId,
            required int bookingId,
            required String sessionKey,
            required String trainingTitle,
          }) async {
            privateHandlers.beginTrainingFeedbackFlow(
              userId: userId,
              bookingId: bookingId,
              sessionKey: sessionKey,
              trainingTitle: trainingTitle,
            );
          },
        ),
        _privateHandlers = privateHandlers,
        _groupHandlers = groupHandlers,
        _googleSheetsWriter = googleSheetsWriter,
        _googleSheetsExportJob = googleSheetsWriter == null
            ? null
            : GoogleSheetsFunnelExportJob(
                onboardingRepository: onboardingRepository,
                writer: googleSheetsWriter,
                sheetTitle: config.googleSheetsWriteSheetTitle,
                adminAnalyticsService: AdminAnalyticsService(
                  bookingRepository: bookingRepository,
                  onboardingRepository: onboardingRepository,
                  subscriptionRepository: subscriptionRepository,
                ),
                economicSummaryService: EconomicSummaryService(
                  bookingRepository: bookingRepository,
                  catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
                ),
                noblesListService: NoblesListService(
                  bookingRepository: bookingRepository,
                  catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
                ),
                conversationLogRepository: conversationLogRepository,
                adminUserIds: config.adminUserIds,
                recentActionsLimit: config.googleSheetsRecentActionsLimit,
              ) {
    final exportJob = _googleSheetsExportJob;
    if (exportJob != null) {
      _privateHandlers.bindGoogleSheetsExport(
        () => _jobScheduler.launch('google sheets funnel export', exportJob.run),
      );
    }
  }

  final AppConfig _config;
  final TelegramClient _client;
  final TrainingScheduleRepository _scheduleRepository;
  final JobScheduler _jobScheduler;
  final ScheduleSyncJob _scheduleSyncJob;
  final ScheduleRetentionJob _scheduleRetentionJob;
  final PaymentReminderJob _paymentReminderJob;
  final StarterBonusReminderJob _starterBonusReminderJob;
  final WelcomeCleanupJob _welcomeCleanupJob;
  final SubscriptionRenewalJob _subscriptionRenewalJob;
  final TrainingDayPromoJob _trainingDayPromoJob;
  final ScheduleBroadcastJob _scheduleBroadcastJob;
  final ReferralBroadcastJob _referralBroadcastJob;
  final EconomicSummaryJob _economicSummaryJob;
  final OnboardingNudgeJob _onboardingNudgeJob;
  final GroupInviteNudgeJob _groupInviteNudgeJob;
  final TrainingFeedbackJob _trainingFeedbackJob;
  final PrivateHandlers _privateHandlers;
  final GroupHandlers _groupHandlers;
  final GoogleSheetsWriter? _googleSheetsWriter;
  final GoogleSheetsFunnelExportJob? _googleSheetsExportJob;

  static const int _maxConflictRetries = 3;

  bool _stopping = false;
  int _exitCode = 0;
  int _conflictRetries = 0;
  int _offset = 0;
  bool _clientClosed = false;
  bool _googleSheetsWriterClosed = false;
  final List<Timer> _timers = <Timer>[];

  int get exitCode => _exitCode;

  Future<void> start() async {
    await _initializeLongPolling();
    final initialRefreshOk = await _scheduleRepository.refresh(force: true);
    if (!initialRefreshOk) {
      l.w('Initial schedule refresh failed. Continuing with available cache.');
    }
    _schedulePeriodic(
      Duration(seconds: _config.scheduleSyncIntervalSeconds),
      'schedule sync',
      _scheduleSyncJob.run,
    );
    _schedulePeriodic(
      const Duration(hours: 1),
      'schedule retention',
      _scheduleRetentionJob.run,
    );
    _schedulePeriodic(const Duration(minutes: 5), 'payment reminder', _paymentReminderJob.run);
    _schedulePeriodic(
      const Duration(minutes: 30),
      'starter bonus reminder',
      _starterBonusReminderJob.run,
    );
    _schedulePeriodic(const Duration(seconds: 20), 'welcome cleanup', _welcomeCleanupJob.run);
    _schedulePeriodic(const Duration(minutes: 30), 'economic summary', _economicSummaryJob.run);
    _schedulePeriodic(
      const Duration(minutes: 30),
      'subscription renewal',
      _subscriptionRenewalJob.run,
    );
    _schedulePeriodic(const Duration(minutes: 1), 'training day promo', _trainingDayPromoJob.run);
    _schedulePeriodic(const Duration(minutes: 1), 'schedule broadcast', _scheduleBroadcastJob.run);
    _schedulePeriodic(const Duration(minutes: 1), 'referral broadcast', _referralBroadcastJob.run);
    _schedulePeriodic(const Duration(minutes: 10), 'onboarding nudge', _onboardingNudgeJob.run);
    _schedulePeriodic(const Duration(hours: 1), 'group invite nudge', _groupInviteNudgeJob.run);
    _schedulePeriodic(const Duration(minutes: 10), 'training feedback', _trainingFeedbackJob.run);
    final googleSheetsExportJob = _googleSheetsExportJob;
    if (googleSheetsExportJob != null) {
      _schedulePeriodic(
        Duration(seconds: _config.googleSheetsWriteIntervalSeconds),
        'google sheets funnel export',
        googleSheetsExportJob.run,
      );
      _jobScheduler.launch('google sheets funnel export', googleSheetsExportJob.run);
    }
    _jobScheduler.launch('economic summary', _economicSummaryJob.run);
    _jobScheduler.launch('subscription renewal', _subscriptionRenewalJob.run);
    _jobScheduler.launch('training day promo', _trainingDayPromoJob.run);
    _jobScheduler.launch('schedule broadcast', _scheduleBroadcastJob.run);
    _jobScheduler.launch('referral broadcast', _referralBroadcastJob.run);

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
            await _jobScheduler.runTracked(() => _handleUpdate(update));
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
    await _jobScheduler.waitForIdle();
    _closeClient();
    await _closeGoogleSheetsWriter();
  }

  Future<void> _handleUpdate(Map<String, dynamic> update) async {
    final privateHandled = await _privateHandlers.handle(update);
    if (privateHandled) {
      return;
    }
    await _groupHandlers.handleUpdate(update);
  }

  Future<void> stop() async {
    if (!_stopping) {
      _stopping = true;
      for (final timer in _timers) {
        timer.cancel();
      }
      _timers.clear();
      _closeClient();
      await _jobScheduler.waitForIdle();
    }
    await _closeGoogleSheetsWriter();
  }

  void _schedulePeriodic(
    Duration period,
    String name,
    Future<void> Function() action,
  ) {
    _timers.add(
      Timer.periodic(period, (_) {
        if (_stopping) {
          return;
        }
        _jobScheduler.launch(name, action);
      }),
    );
  }

  Future<void> _initializeLongPolling() async {
    try {
      await _client.deleteWebhook();
    } on Object catch (error, stackTrace) {
      l.w('Failed to reset Telegram webhook before polling: $error', stackTrace);
    }
  }

  Future<void> _closeGoogleSheetsWriter() async {
    if (_googleSheetsWriterClosed) {
      return;
    }
    _googleSheetsWriterClosed = true;
    await _googleSheetsWriter?.close();
  }

  void _closeClient() {
    if (_clientClosed) {
      return;
    }
    _clientClosed = true;
    _client.close();
  }
}
