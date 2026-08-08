import 'dart:async';

import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/admin_analytics_service.dart';
import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/application/broadcast_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/application/onboarding_service.dart';
import 'package:dvor_chatbot/src/application/payment_review_service.dart';
import 'package:dvor_chatbot/src/application/schedule_query_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/admin_gate.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/admin_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/booking_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_context.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_request_context.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_static_commands.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_update_router.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/schedule_handler.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/dvor_team_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/promo_code_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:dvor_chatbot/src/domain/frank_by_basta.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:l/l.dart';

part 'private/private_handlers_booking.part.dart';
part 'private/private_handlers_payment.part.dart';
part 'private/private_handlers_admin.part.dart';
part 'private/private_handlers_onboarding.part.dart';
part 'private/private_handlers_bonuses.part.dart';
part 'private/private_handlers_schedule.part.dart';
part 'private/private_handlers_dispatch.part.dart';
part 'private/private_handlers_dispatch_back.part.dart';
part 'private/private_handlers_dispatch_user.part.dart';
part 'private/private_handlers_dispatch_user_booking.part.dart';
part 'private/private_handlers_dispatch_user_payment.part.dart';
part 'private/private_handlers_dispatch_admin.part.dart';
part 'private/private_handlers_dispatch_admin_menu.part.dart';
part 'private/private_handlers_dispatch_admin_tools.part.dart';
part 'private/private_handlers_dispatch_admin_bookings.part.dart';
part 'private/private_handlers_dispatch_admin_moderation.part.dart';
part 'private/private_handlers_dispatch_user_profile.part.dart';
part 'private/private_handlers_dispatch_inline_callbacks.part.dart';
part 'private/private_handlers_dispatch_user_actions.part.dart';

final class PrivateHandlers {
  static const String _paymentChoiceFullMarker = '__payment_choice_full__';
  static const String _paymentChoicePartialMarker = '__payment_choice_partial__';
  static const int _proIncludedTrainingsPerPeriod = 8;
  static const int _adminBookingsPageSize = 8;
  static const int _myBookingsPageSize = 8;

  PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    SubscriptionRepository subscriptionRepository = const NoopSubscriptionRepository(),
    OnboardingRepository onboardingRepository = const NoopOnboardingRepository(),
    ConversationLogRepository conversationLogRepository = const NoopConversationLogRepository(),
    TrainerDirectoryRepository trainerDirectoryRepository = const NoopTrainerDirectoryRepository(),
    DvorTeamRepository dvorTeamRepository = const NoopDvorTeamRepository(),
    PromoCodeRepository promoCodeRepository = const NoopPromoCodeRepository(),
    required MessageTemplates templates,
    required Set<int> adminUserIds,
    int? adminChatId,
    int? targetChatId,
    GroupAnnouncementService? groupAnnouncements,
    bool onboardingDripEnabled = false,
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _bookingRepository = bookingRepository,
        _subscriptionRepository = subscriptionRepository,
        _onboardingRepository = onboardingRepository,
        _conversationLogRepository = conversationLogRepository,
        _trainerDirectoryRepository = trainerDirectoryRepository,
        _dvorTeamRepository = dvorTeamRepository,
        _promoCodeRepository = promoCodeRepository,
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _targetChatId = targetChatId,
        _groupAnnouncements = groupAnnouncements ?? GroupAnnouncementService(sender: sender),
        _onboardingService = OnboardingService(
          onboardingRepository: onboardingRepository,
          dripEnabled: onboardingDripEnabled,
        ),
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final BookingRepository _bookingRepository;
  final SubscriptionRepository _subscriptionRepository;
  final OnboardingRepository _onboardingRepository;
  final ConversationLogRepository _conversationLogRepository;
  final TrainerDirectoryRepository _trainerDirectoryRepository;
  final DvorTeamRepository _dvorTeamRepository;
  final PromoCodeRepository _promoCodeRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final int? _targetChatId;
  final GroupAnnouncementService _groupAnnouncements;
  final OnboardingService _onboardingService;
  final DateTime Function() _nowProvider;
  final Map<int, PrivateFlowState> _flowByUserId = <int, PrivateFlowState>{};
  final Set<int> _adminsInClientMode = <int>{};
  final Map<int, Timer> _broadcastMediaFinalizeTimers = <int, Timer>{};
  final Map<int, String> _broadcastActiveMediaGroupIds = <int, String>{};
  final Set<String> _lowCapacityNotifiedTrainingKeys = <String>{};
  final Set<String> _fullCapacityNotifiedTrainingKeys = <String>{};
  late final ActivityCatalogService _catalogService =
      ActivityCatalogService(scheduleRepository: _scheduleRepository);
  late final ScheduleQueryService _scheduleQueryService = ScheduleQueryService(
    catalogService: _catalogService,
    trainerDirectoryRepository: _trainerDirectoryRepository,
    templates: _templates,
  );
  late final BookingPolicyService _bookingPolicyService =
      BookingPolicyService(catalogService: _catalogService);
  late final PaymentReviewService _paymentReviewService =
      PaymentReviewService(bookingRepository: _bookingRepository, catalogService: _catalogService);
  late final EconomicSummaryService _economicSummaryService = EconomicSummaryService(
      bookingRepository: _bookingRepository, catalogService: _catalogService);
  late final AdminAnalyticsService _adminAnalyticsService = AdminAnalyticsService(
    bookingRepository: _bookingRepository,
    onboardingRepository: _onboardingRepository,
    subscriptionRepository: _subscriptionRepository,
  );
  late final NoblesListService _noblesListService = NoblesListService(
    bookingRepository: _bookingRepository,
    catalogService: _catalogService,
    nowProvider: _nowProvider,
  );
  late final BroadcastService _broadcastService = BroadcastService(
    sender: _sender,
    onboardingRepository: _onboardingRepository,
    groupChatId: _targetChatId,
  );
  final PrivateUpdateRouter _updateRouter = const PrivateUpdateRouter();
  final ScheduleHandler _scheduleHandler = const ScheduleHandler();
  final BookingHandler _bookingHandler = const BookingHandler();
  late final AdminGate _adminGate = AdminGate(_adminUserIds);
  late final AdminHandler _adminHandler = AdminHandler(gate: _adminGate);
  final PrivateStaticCommands _staticCommands = const PrivateStaticCommands();

  void beginTrainingFeedbackFlow({
    required int userId,
    required int bookingId,
    required String sessionKey,
    required String trainingTitle,
  }) {
    _flowByUserId[userId] = PrivateFlowState(
      step: PrivateFlowStep.awaitingTrainingFeedbackRating,
      availableTrainings: const <TrainingInfo>[],
      feedbackBookingId: bookingId,
      feedbackSessionKey: sessionKey,
      feedbackTrainingTitle: trainingTitle,
    );
  }
}

typedef _PrivateFlowState = PrivateFlowState;
typedef _PrivateFlowStep = PrivateFlowStep;
typedef _ActivityCategory = ActivityCategory;
typedef _AdminClientNotificationAction = AdminClientNotificationAction;

enum _FreeTrainingBonusType { starter, referral, everyFifth }

enum _EconomicSummaryRange {
  currentWeek('за текущую неделю'),
  previousWeek('за прошлую неделю'),
  currentMonth('за текущий месяц'),
  previousMonth('за прошлый месяц');

  const _EconomicSummaryRange(this.label);

  final String label;
}
