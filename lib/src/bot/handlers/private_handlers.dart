import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/application/payment_review_service.dart';
import 'package:dvor_chatbot/src/application/schedule_query_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/admin_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/booking_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_context.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_static_commands.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_update_router.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/schedule_handler.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class PrivateHandlers {
  static const String _paymentChoiceFullMarker = '__payment_choice_full__';
  static const String _paymentChoicePartialMarker = '__payment_choice_partial__';
  static const int _proIncludedTrainingsPerPeriod = 8;
  static const int _adminBookingsPageSize = 8;
  static const int _myBookingsPageSize = 8;
  static const int _yogaTrainerUserId = 857655217;

  PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    SubscriptionRepository subscriptionRepository = const NoopSubscriptionRepository(),
    OnboardingRepository onboardingRepository = const NoopOnboardingRepository(),
    TrainerDirectoryRepository trainerDirectoryRepository = const NoopTrainerDirectoryRepository(),
    required MessageTemplates templates,
    required Set<int> adminUserIds,
    int? adminChatId,
    int? targetChatId,
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _bookingRepository = bookingRepository,
        _subscriptionRepository = subscriptionRepository,
        _onboardingRepository = onboardingRepository,
        _trainerDirectoryRepository = trainerDirectoryRepository,
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final BookingRepository _bookingRepository;
  final SubscriptionRepository _subscriptionRepository;
  final OnboardingRepository _onboardingRepository;
  final TrainerDirectoryRepository _trainerDirectoryRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final int? _targetChatId;
  final DateTime Function() _nowProvider;
  final Map<int, PrivateFlowState> _flowByUserId = <int, PrivateFlowState>{};
  final Set<String> _lowCapacityNotifiedTrainingKeys = <String>{};
  final Set<String> _fullCapacityNotifiedTrainingKeys = <String>{};
  int? _lastCapacityGroupMessageId;
  _CapacityGroupNotificationType? _lastCapacityGroupMessageType;
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
  late final NoblesListService _noblesListService = NoblesListService(
    bookingRepository: _bookingRepository,
    catalogService: _catalogService,
    nowProvider: _nowProvider,
  );
  final PrivateUpdateRouter _updateRouter = const PrivateUpdateRouter();
  final ScheduleHandler _scheduleHandler = const ScheduleHandler();
  final BookingHandler _bookingHandler = const BookingHandler();
  final AdminHandler _adminHandler = const AdminHandler();
  final PrivateStaticCommands _staticCommands = const PrivateStaticCommands();

  Future<bool> handle(Map<String, dynamic> update) async {
    final context = extractPrivateMessageContext(update);
    if (context == null) {
      return false;
    }
    final chat = context.chat;
    if (chat['type']?.toString() != 'private') {
      return false;
    }
    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    final callbackQueryId = context.callbackQueryId;
    if (callbackQueryId != null) {
      try {
        await _sender.answerCallbackQuery(callbackQueryId);
      } on Object catch (error, stackTrace) {
        l.w('Failed to acknowledge callback query $callbackQueryId: $error', stackTrace);
      }
    }
    final text = context.text;
    final rawUserId = context.from?['id'];
    final userId = rawUserId is int ? rawUserId : null;
    final isConfiguredAdmin = userId != null && _adminUserIds.contains(userId);
    final isAdmin = isConfiguredAdmin;
    final isYogaTrainer = userId == _yogaTrainerUserId;
    final canRunAdminAction = _adminHandler.canRunAdminAction(isAdmin: isConfiguredAdmin);
    final canRunParticipantsAction = canRunAdminAction || isYogaTrainer;
    final flowState = userId == null ? null : _flowByUserId[userId];
    final paymentProof = extractPaymentProof(context.message);
    if (_isIgnorableServiceMessage(context.message)) {
      return true;
    }

    final handledStaticCommand = await _staticCommands.handle(
      text: text,
      chatId: chatId,
      userId: userId,
      isAdmin: isAdmin,
      flowByUserId: _flowByUserId,
      trainerDirectoryRepository: _trainerDirectoryRepository,
      onboardingRepository: _onboardingRepository,
      sender: _sender,
      templates: _templates,
      canViewParticipantsList: canRunParticipantsAction,
      onStartCleanup: _handleStartCleanup,
      onEveryFifthUnlocked: _maybeNotifyEveryFifthRewardUnlocked,
      onPinWelcomeMessage: _tryPinWelcomeMessage,
      username: context.from?['username']?.toString(),
    );
    if (handledStaticCommand) {
      return true;
    }

    if (text == MessageTemplates.buttonBack) {
      if (userId == null) {
        return false;
      }
      switch (flowState?.step) {
        case _PrivateFlowStep.selectingScheduleCategory:
        case _PrivateFlowStep.viewingCoachingStaff:
        case _PrivateFlowStep.selectingBookingCategory:
        case _PrivateFlowStep.selectingParticipantsCategory:
        case _PrivateFlowStep.selectingPaymentsQueueCategory:
        case _PrivateFlowStep.selectingEconomicSummaryPeriod:
        case _PrivateFlowStep.viewingSubscriptionOverview:
        case _PrivateFlowStep.selectingBookingListSegment:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case _PrivateFlowStep.selectingTrainerProfile:
          final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
          _flowByUserId[userId] = flowState!.copyWith(step: _PrivateFlowStep.viewingCoachingStaff);
          await _sender.sendMessage(
            chatId,
            _templates.coachingStaff(trainers),
            replyMarkup: _templates.coachingStaffActionsKeyboard(),
            parseMode: 'HTML',
            disableWebPagePreview: true,
          );
          return true;
        case _PrivateFlowStep.selectingOutdoorDetailEvent:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingScheduleCategory,
            selectedOutdoorActivity: null,
            outdoorDetailType: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseScheduleCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingOutdoorDetailType:
          final selectedCategory = flowState?.selectedCategory;
          if (selectedCategory == null || !_isOutdoorCategory(selectedCategory)) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
            );
            return true;
          }
          final outdoorItems = _catalogService.outdoorItems(selectedCategory);
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingOutdoorDetailEvent,
            selectedOutdoorActivity: null,
            outdoorDetailType: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseOutdoorEventForDetails(selectedCategory),
            replyMarkup: _templates.outdoorSelectionKeyboard(outdoorItems),
          );
          return true;
        case _PrivateFlowStep.viewingScheduleCategory:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingScheduleCategory);
          await _sender.sendMessage(
            chatId,
            _templates.chooseScheduleCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingTraining:
          final selectedCategory = flowState?.selectedCategory;
          if (selectedCategory != null && flowState?.bookingFromSchedulePreview == true) {
            await _refreshTrainerDirectoryForSchedule();
            _flowByUserId[userId] = flowState!.copyWith(
              step: _PrivateFlowStep.viewingScheduleCategory,
              availableTrainings: const <TrainingInfo>[],
            );
            await _sender.sendMessage(
              chatId,
              _scheduleTextByCategory(selectedCategory),
              replyMarkup: _templates.scheduleCategoryActionsKeyboard(
                showOutdoorActions: _isOutdoorCategory(selectedCategory),
              ),
              parseMode: 'HTML',
              disableWebPagePreview: true,
            );
            return true;
          }
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingBookingCategory,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.paymentConfirmation:
          final items = flowState!.availableTrainings;
          _flowByUserId[userId] = flowState.copyWith(step: _PrivateFlowStep.selectingTraining);
          await _sender.sendMessage(
            chatId,
            _templates.chooseTrainingForBooking(items),
            replyMarkup: _templates.bookingSelectionKeyboard(items),
          );
          return true;
        case _PrivateFlowStep.confirmingSubscriptionPayment:
          final now = _nowProvider();
          final membership = await _subscriptionRepository.getMembership(
            userId,
            now: now,
          );
          final remainingProTrainings = await _proIncludedTrainingRemainingCount(
            userId: userId,
            membership: membership,
          );
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.viewingSubscriptionOverview,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionOverview(
              membershipLevel: membership.level,
              activeUntil: membership.activeUntil,
              remainingProTrainings: remainingProTrainings,
            ),
            replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.selectingBookingAction:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingBookingToManage,
            selectedBooking: null,
          );
          await _sendMyBookingListPage(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingBookingToManage:
          await _openMyBookingListSegment(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingRescheduleTraining:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.bookingActions(selectedBooking),
            replyMarkup: _bookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingManagementAction:
        case _PrivateFlowStep.selectingAdminSubscriptionsAction:
        case _PrivateFlowStep.selectingAdminSubscriptionFilter:
        case _PrivateFlowStep.enteringAdminSubscriptionSearchQuery:
        case _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate:
        case _PrivateFlowStep.enteringAdminSubscriptionReasonComment:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingListSegment:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementAction(),
            replyMarkup: _templates.adminBookingManagementKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingListCategory:
          await _openAdminBookingListSegment(
            chatId: chatId,
            userId: userId,
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingFromList:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingAdminBookingListCategory,
            availableBookings: const <TrainingBooking>[],
            selectedBooking: null,
            adminBookingsPage: 0,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingAction:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingAdminBookingFromList,
            selectedBooking: null,
          );
          await _sendAdminBookingListPage(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingAdminBookingEditField:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.adminBookingActions(selectedBooking),
            replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingEditStatus:
        case _PrivateFlowStep.enteringAdminBookingUsername:
        case _PrivateFlowStep.selectingAdminBookingEditEvent:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditField);
          await _sender.sendMessage(
            chatId,
            _templates.chooseAdminBookingEditField(selectedBooking),
            replyMarkup: _templates.adminBookingEditFieldsKeyboard(),
          );
          return true;
        case _PrivateFlowStep.confirmingAdminBookingDelete:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.adminBookingActions(selectedBooking),
            replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateCategory:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementAction(),
            replyMarkup: _templates.adminBookingManagementKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateEvent:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminCreateCategory,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.enteringAdminCreateUsername:
          final trainings = flowState!.availableTrainings;
          _flowByUserId[userId] =
              flowState.copyWith(step: _PrivateFlowStep.selectingAdminCreateEvent);
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingEvent(trainings),
            replyMarkup: _templates.bookingSelectionKeyboard(trainings),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateStatus:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.enteringAdminCreateUsername);
          await _sender.sendMessage(
            chatId,
            _templates.createBookingAskUsername(),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case _PrivateFlowStep.confirmingAdminCreate:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminCreateStatus);
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingPaymentStatus(),
            replyMarkup: _templates.bookingPaymentStatusKeyboard(),
          );
          return true;
        case null:
          await _sender.sendMessage(
            chatId,
            'Ты уже в главном меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
      }
    }

    if (text != null && (text == MessageTemplates.buttonBookTraining || text.startsWith('/book'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: context.from?['username']?.toString(),
      );
      if (flowState?.step == _PrivateFlowStep.selectingOutdoorDetailType &&
          flowState?.selectedOutdoorActivity != null) {
        final selectedTraining =
            _catalogService.toBookableInfo(flowState!.selectedOutdoorActivity!);
        await _createOrContinueBooking(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          flowState: flowState,
          selectedTraining: selectedTraining,
          username: context.from?['username']?.toString(),
          onParticipantsLimitReplyMarkup: _templates.outdoorDetailTypeKeyboard(),
        );
        return true;
      }
      final scheduleCategoryContext = flowState?.step == _PrivateFlowStep.viewingScheduleCategory
          ? flowState?.selectedCategory
          : null;
      if (scheduleCategoryContext != null) {
        await _openBookingByCategory(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          category: scheduleCategoryContext,
          fromSchedulePreview: true,
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookingCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseBookingCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text == MessageTemplates.buttonSubscription ||
        text == MessageTemplates.buttonRenewSubscription) {
      if (userId == null) {
        return false;
      }
      final now = _nowProvider();
      final membership = await _subscriptionRepository.getMembership(
        userId,
        now: now,
      );
      final remainingProTrainings = await _proIncludedTrainingRemainingCount(
        userId: userId,
        membership: membership,
      );
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.viewingSubscriptionOverview,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.subscriptionOverview(
          membershipLevel: membership.level,
          activeUntil: membership.activeUntil,
          remainingProTrainings: remainingProTrainings,
        ),
        replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingCoachingStaff &&
        text == MessageTemplates.buttonCoachDetails) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      if (trainers.isEmpty) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.coachingStaff(trainers),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(step: _PrivateFlowStep.selectingTrainerProfile);
      await _sender.sendMessage(
        chatId,
        _templates.chooseTrainerProfile(trainers),
        replyMarkup: _templates.trainerSelectionKeyboard(trainers),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingCoachingStaff &&
        text != null &&
        !text.startsWith('/')) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      await _sender.sendMessage(
        chatId,
        _templates.coachingStaff(trainers),
        replyMarkup: _templates.coachingStaffActionsKeyboard(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingTrainerProfile &&
        text != null &&
        !text.startsWith('/')) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      final index = _parseTrainerSelectionIndex(text);
      if (index == null || index < 1 || index > trainers.length) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownTrainerSelection(),
          replyMarkup: _templates.trainerSelectionKeyboard(trainers),
        );
        return true;
      }
      final trainer = trainers[index - 1];
      await _sender.sendMessage(
        chatId,
        _templates.trainerProfile(trainer),
        replyMarkup: _templates.trainerSelectionKeyboard(trainers),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingScheduleCategory &&
        (text == MessageTemplates.buttonOutdoorEquipment ||
            text == MessageTemplates.buttonOutdoorItinerary)) {
      final category = flowState?.selectedCategory;
      if (category == null || !_isOutdoorCategory(category)) {
        return true;
      }
      final outdoorItems = _catalogService.outdoorItems(category);
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingOutdoorDetailEvent,
        selectedOutdoorActivity: null,
        outdoorDetailType: null,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseOutdoorEventForDetails(category),
        replyMarkup: _templates.outdoorSelectionKeyboard(outdoorItems),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingOutdoorDetailEvent &&
        text != null &&
        !text.startsWith('/')) {
      final category = flowState?.selectedCategory;
      if (category == null || !_isOutdoorCategory(category)) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final outdoorItems = _catalogService.outdoorItems(category);
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > outdoorItems.length) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownOutdoorSelection(),
          replyMarkup: _templates.outdoorSelectionKeyboard(outdoorItems),
        );
        return true;
      }
      final selectedOutdoor = outdoorItems[index - 1];
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingOutdoorDetailType,
        selectedOutdoorActivity: selectedOutdoor,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseOutdoorDetailType(selectedOutdoor),
        replyMarkup: _templates.outdoorDetailTypeKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingOutdoorDetailType &&
        text != null &&
        !text.startsWith('/')) {
      final selectedOutdoor = flowState?.selectedOutdoorActivity;
      if (selectedOutdoor == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownOutdoorSelection(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonOutdoorEquipment) {
        await _sender.sendMessage(
          chatId,
          _templates.outdoorEquipmentDetails(selectedOutdoor),
          replyMarkup: _templates.outdoorDetailTypeKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      if (text == MessageTemplates.buttonOutdoorItinerary) {
        await _sender.sendMessage(
          chatId,
          _templates.outdoorItineraryDetails(selectedOutdoor),
          replyMarkup: _templates.outdoorDetailTypeKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.chooseOutdoorDetailType(selectedOutdoor),
        replyMarkup: _templates.outdoorDetailTypeKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingScheduleCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      if (_isOutdoorCategory(category)) {
        final outdoorItems = _catalogService.outdoorItems(category);
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingOutdoorDetailEvent,
          availableTrainings: const <TrainingInfo>[],
          selectedCategory: category,
        );
        await _refreshTrainerDirectoryForSchedule();
        await _sender.sendMessage(
          chatId,
          _scheduleTextByCategory(category),
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
        await _sender.sendMessage(
          chatId,
          _templates.chooseOutdoorEventForDetails(category),
          replyMarkup: _templates.outdoorSelectionKeyboard(outdoorItems),
        );
      } else {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.viewingScheduleCategory,
          availableTrainings: const <TrainingInfo>[],
          selectedCategory: category,
        );
        await _refreshTrainerDirectoryForSchedule();
        await _sender.sendMessage(
          chatId,
          _scheduleTextByCategory(category),
          replyMarkup: _templates.scheduleCategoryActionsKeyboard(
            showOutdoorActions: _isOutdoorCategory(category),
          ),
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
      }
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      await _openBookingByCategory(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        category: category,
        fromSchedulePreview: false,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingParticipantsCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      _flowByUserId.remove(userId);
      await _sendParticipantsByCategory(
        chatId: chatId,
        category: category,
        isAdmin: isAdmin,
        canViewParticipantsList: canRunParticipantsAction,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingPaymentsQueueCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        final counters = await _paymentReviewService.queueCounters();
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
            trainings: counters.trainings,
            yoga: counters.yoga,
            hikes: counters.hikes,
            trails: counters.trails,
          ),
        );
        return true;
      }
      _flowByUserId.remove(userId);
      await _sendPaymentsQueueByCategory(
        chatId: chatId,
        category: category,
        isAdmin: isAdmin,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingTraining &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > flowState!.availableTrainings.length) {
        await _sender.sendMessage(
          chatId,
          _bookingHandler.unknownSelectionText(),
          replyMarkup: _templates.bookingSelectionKeyboard(flowState!.availableTrainings),
        );
        return true;
      }
      final selectedTraining = flowState.availableTrainings[index - 1];
      final username = context.from?['username']?.toString();
      await _createOrContinueBooking(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        flowState: flowState,
        selectedTraining: selectedTraining,
        username: username,
        onParticipantsLimitReplyMarkup:
            _templates.bookingSelectionKeyboard(flowState.availableTrainings),
      );
      return true;
    }

    if (text != null && (text == MessageTemplates.buttonProfile || text.startsWith('/profile'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: context.from?['username']?.toString(),
      );
      final now = _nowProvider();
      final bookings = await _bookingRepository.listUserBookings(userId);
      final everyFifthProgress = await _bookingRepository.getEveryFifthRewardProgress(
        userId,
        now: now,
      );
      final starterBonusAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
      final subscriptionSnapshot = await _subscriptionRepository.getUserSnapshot(userId, now: now);
      final membership = subscriptionSnapshot.membership;
      final remainingProTrainings = await _proIncludedTrainingRemainingCount(
        userId: userId,
        membership: membership,
      );
      final activeBookings = bookings
          .where(
            (booking) =>
                booking.status != BookingStatus.cancelled && !booking.startsAt.isBefore(now),
          )
          .toList(growable: false);
      final visitedBookings = bookings
          .where(
            (booking) =>
                booking.status != BookingStatus.cancelled && booking.startsAt.isBefore(now),
          )
          .toList(growable: false);
      final cancelledBookings =
          bookings.where((booking) => booking.status == BookingStatus.cancelled).length;
      await _sender.sendMessage(
        chatId,
        _templates.profileOverview(
          totalBookings: bookings.length,
          activeBookings: activeBookings.length,
          visitedBookings: visitedBookings.length,
          cancelledBookings: cancelledBookings,
          completedTrainingsCount: everyFifthProgress.qualifiedTrainingsCount,
          availableEveryFifthRewards: everyFifthProgress.availableRewardsCount,
          starterBonusAvailable: starterBonusAvailable,
          membershipLevel: membership.level,
          subscriptionActiveUntil: membership.activeUntil,
          subscriptionRemainingProTrainings: remainingProTrainings,
          subscriptionRequestStatusLine:
              _templates.subscriptionStatusLineFromSnapshot(subscriptionSnapshot),
          subscriptionTotalApprovedCount: subscriptionSnapshot.totalApprovedCount,
          subscriptionCurrentPeriodStart: subscriptionSnapshot.latestActiveRequest?.activeFrom,
          now: now,
        ),
        replyMarkup: _templates.profileActionsKeyboard(),
        parseMode: 'HTML',
      );
      _flowByUserId.remove(userId);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonProfileBookings || text.startsWith('/my_bookings'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: context.from?['username']?.toString(),
      );
      final bookings = await _bookingRepository.listUserBookings(userId);
      if (bookings.isEmpty) {
        await _sender.sendMessage(
          chatId,
          'У тебя пока нет записей на мероприятия 🙃',
          replyMarkup: _templates.profileActionsKeyboard(),
        );
        return true;
      }
      final now = _nowProvider();
      final currentCount =
          bookings.where((booking) => !_isArchivedBookingAt(booking, now: now)).length;
      final pastCount = bookings.length - currentCount;
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookingListSegment,
        availableTrainings: const <TrainingInfo>[],
        availableBookings: bookings,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseMyBookingsSegment(),
        replyMarkup: _templates.myBookingSegmentKeyboard(
          currentCount: currentCount,
          pastCount: pastCount,
        ),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingListSegment &&
        text != null &&
        !text.startsWith('/')) {
      final past = _parseMyBookingSegmentSelection(text);
      if (past == null) {
        final selectedBookingId = _parseBookingSelectionId(text);
        if (selectedBookingId != null) {
          final now = _nowProvider();
          final currentBookings = flowState!.availableBookings
              .where((booking) => !_isArchivedBookingAt(booking, now: now))
              .toList(growable: false);
          TrainingBooking? selectedBooking;
          for (final booking in currentBookings) {
            if (booking.id == selectedBookingId) {
              selectedBooking = booking;
              break;
            }
          }
          if (selectedBooking != null) {
            _flowByUserId[userId] = flowState.copyWith(
              step: _PrivateFlowStep.selectingBookingAction,
              adminViewingArchived: false,
              availableBookings: currentBookings,
              selectedBooking: selectedBooking,
            );
            await _sender.sendMessage(
              chatId,
              _templates.bookingActions(selectedBooking),
              replyMarkup: _bookingActionsKeyboard(selectedBooking),
            );
            return true;
          }
        }
        await _openMyBookingListSegment(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingBookingToManage,
        adminViewingArchived: past,
        selectedBooking: null,
        adminBookingsPage: 0,
      );
      await _sendMyBookingListPage(chatId: chatId, userId: userId);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingToManage &&
        text != null &&
        !text.startsWith('/')) {
      if (text == MessageTemplates.buttonBookingsNextPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage + 1,
        );
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonBookingsPreviousPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage - 1,
        );
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      final currentFlow = flowState!;
      final selectedBookingId = _parseBookingSelectionId(text);
      TrainingBooking? selectedBooking;
      for (final booking in currentFlow.availableBookings) {
        if (booking.id == selectedBookingId) {
          selectedBooking = booking;
          break;
        }
      }
      if (selectedBooking == null) {
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = currentFlow.copyWith(
        step: _PrivateFlowStep.selectingBookingAction,
        selectedBooking: selectedBooking,
      );
      await _sender.sendMessage(
        chatId,
        _templates.bookingActions(selectedBooking),
        replyMarkup: _bookingActionsKeyboard(selectedBooking),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonRescheduleBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null || !_bookingPolicyService.canReschedule(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingRescheduleNotAvailable(selectedBooking),
          replyMarkup: _templates.bookingActionsKeyboard(
            canReschedule: false,
            canCancel: selectedBooking != null &&
                _isOutdoorCategory(_catalogService.categoryForBooking(selectedBooking)),
            canRepeat: selectedBooking != null,
          ),
        );
        return true;
      }
      final trainings =
          _bookableItemsByCategory(_catalogService.categoryForBooking(selectedBooking));
      if (trainings.isEmpty) {
        await _sender.sendMessage(
          chatId,
          _templates.chooseTrainingForReschedule(const <TrainingInfo>[], booking: selectedBooking),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingRescheduleTraining,
        availableTrainings: trainings,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseTrainingForReschedule(trainings, booking: selectedBooking),
        replyMarkup: _templates.bookingSelectionKeyboard(trainings),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonCancelBooking) {
      final selectedBooking = flowState?.selectedBooking;
      final category =
          selectedBooking == null ? null : _catalogService.categoryForBooking(selectedBooking);
      if (selectedBooking == null ||
          category == null ||
          !_bookingPolicyService.supportsCancellation(category)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelNotAvailable(selectedBooking),
          replyMarkup: _templates.bookingActionsKeyboard(
            canReschedule:
                selectedBooking != null && _bookingPolicyService.canReschedule(selectedBooking),
            canCancel: false,
            canRepeat: selectedBooking != null,
          ),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(selectedBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      final cancelResult = await _bookingRepository.cancelBooking(
        userId: userId,
        bookingId: selectedBooking.id,
      );
      _flowByUserId.remove(userId);
      if (cancelResult.outcome == BookingActionOutcome.success && cancelResult.booking != null) {
        if (_shouldNotifyAdminAboutBookingCancellation(selectedBooking)) {
          await _notifyAdminAboutBookingCancelled(selectedBooking);
        }
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelled(cancelResult.booking!),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.bookingNotFound(selectedBooking.id),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonCompletePayment) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null || selectedBooking.status != BookingStatus.partialPaid) {
        await _sender.sendMessage(
          chatId,
          selectedBooking == null
              ? _templates.privateFallback()
              : _templates.bookingActions(selectedBooking),
          replyMarkup: selectedBooking == null
              ? _templates.privateMenuKeyboard(isAdmin: isAdmin)
              : _bookingActionsKeyboard(selectedBooking),
        );
        return true;
      }
      await _openPaymentFlowForBooking(
        chatId: chatId,
        userId: userId,
        booking: selectedBooking,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonRepeatBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (selectedBooking.status == BookingStatus.pendingPayment ||
          selectedBooking.status == BookingStatus.partialPaid) {
        await _openPaymentFlowForBooking(
          chatId: chatId,
          userId: userId,
          booking: selectedBooking,
        );
        return true;
      }
      await _openBookingByCategory(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        category: _catalogService.categoryForBooking(selectedBooking),
        fromSchedulePreview: false,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingRescheduleTraining &&
        text != null &&
        !text.startsWith('/')) {
      final currentFlow = flowState!;
      final selectedBooking = currentFlow.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          'Вернул в главное меню 👇',
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > currentFlow.availableTrainings.length) {
        await _sender.sendMessage(
          chatId,
          _bookingHandler.unknownSelectionText(),
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      final targetTraining = currentFlow.availableTrainings[index - 1];
      if (targetTraining.sessionKey == selectedBooking.trainingKey) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingRescheduleSameTraining(),
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      try {
        _bookingPolicyService.ensureReschedulePaymentTypeAllowed(
          booking: selectedBooking,
          targetTraining: targetTraining,
        );
      } on ReschedulePaymentTypeViolationException catch (error) {
        final message = switch (error.violation) {
          ReschedulePaymentTypeViolation.freeToPaid =>
            _templates.bookingRescheduleFreeToPaidNotAllowed(),
          ReschedulePaymentTypeViolation.paidToFree =>
            _templates.bookingReschedulePaidToFreeNotAllowed(),
          ReschedulePaymentTypeViolation.priceMismatch =>
            _templates.bookingReschedulePriceMismatchNotAllowed(),
        };
        await _sender.sendMessage(
          chatId,
          message,
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      final before = selectedBooking;
      final result = await _bookingRepository.rescheduleBooking(
        userId: userId,
        bookingId: selectedBooking.id,
        training: targetTraining,
      );
      switch (result.outcome) {
        case BookingRescheduleOutcome.success:
          _flowByUserId.remove(userId);
          final after = result.booking ?? before;
          await _notifyAdminAboutBookingRescheduled(before: before, after: after);
          await _sender.sendMessage(
            chatId,
            _templates.bookingRescheduled(from: before, to: after),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case BookingRescheduleOutcome.notFound:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            _templates.bookingNotFound(selectedBooking.id),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case BookingRescheduleOutcome.conflict:
          await _sender.sendMessage(
            chatId,
            _templates.bookingRescheduleConflict(),
            replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
          );
          return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        (text == MessageTemplates.buttonPayFully || text == MessageTemplates.buttonPayPartially)) {
      final currentFlow = flowState!;
      final booking = currentFlow.activeBooking;
      if (booking == null || !_isOutdoorCategory(_catalogService.categoryForBooking(booking))) {
        await _sender.sendMessage(
          chatId,
          _templates.paymentProofRequired(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: currentFlow.starterBonusOffered,
            showCancelBooking: booking != null && _canCancelBookingByPolicy(booking),
            showOutdoorPaymentTypeChoice:
                booking != null && _shouldShowOutdoorPaymentTypeChoice(booking),
          ),
        );
        return true;
      }
      final selectedChoice =
          text == MessageTemplates.buttonPayPartially ? PaymentChoice.partial : PaymentChoice.full;
      _flowByUserId[userId] = currentFlow.copyWith(paymentChoice: selectedChoice);
      await _sender.sendMessage(
        chatId,
        _templates.paymentProofRequired(),
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: currentFlow.starterBonusOffered,
          showCancelBooking: _canCancelBookingByPolicy(booking),
          showOutdoorPaymentTypeChoice: true,
        ),
      );
      return true;
    }

    if (text == MessageTemplates.buttonSubscribeApply) {
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.confirmingSubscriptionPayment,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.subscriptionPaymentInstructions(),
        replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingSubscriptionPayment &&
        paymentProof != null) {
      final submitResult = await _subscriptionRepository.submitPaymentRequest(
        userId: userId,
        userUsername: context.from?['username']?.toString(),
        note: paymentProof.caption,
        paymentProofChatId: paymentProof.fromChatId,
        paymentProofMessageId: paymentProof.messageId,
        requestedAt: _nowProvider(),
      );
      _flowByUserId.remove(userId);
      switch (submitResult.outcome) {
        case SubmitSubscriptionRequestOutcome.created:
          final request = submitResult.request;
          if (request != null) {
            await _notifyAdminAboutSubscriptionSubmitted(request);
          }
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionPaymentSubmitted(),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
        case SubmitSubscriptionRequestOutcome.alreadyPending:
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionAlreadyPending(),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingSubscriptionPayment &&
        text != null &&
        !text.startsWith('/')) {
      await _sender.sendMessage(
        chatId,
        _templates.subscriptionPaymentProofRequired(),
        replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        paymentProof != null) {
      final currentFlow = flowState!;
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        bookingId: currentFlow.activeBooking?.id,
        note: _composePaymentNote(
          caption: paymentProof.caption,
          choice: currentFlow.paymentChoice,
        ),
        paymentProofChatId: paymentProof.fromChatId,
        paymentProofMessageId: paymentProof.messageId,
      );
      if (booking != null) {
        await _notifyAdminAboutPaymentSubmitted(booking);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        booking == null ? _templates.noPendingPayment() : _templates.paymentSubmitted(booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        text == MessageTemplates.buttonUseStarterBonus &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation) {
      if (userId == null || flowState == null) {
        return false;
      }
      final activeBooking = flowState.activeBooking;
      final canUseBonus = flowState.starterBonusOffered &&
          activeBooking != null &&
          _catalogService.categoryForBooking(activeBooking) == _ActivityCategory.trainings;
      if (!canUseBonus) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: activeBooking != null && _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice:
                activeBooking != null && _shouldShowOutdoorPaymentTypeChoice(activeBooking),
          ),
        );
        return true;
      }
      final bonusType = await _resolveFreeTrainingBonusType(userId);
      if (bonusType == null) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(activeBooking),
          ),
        );
        return true;
      }
      final updated = switch (bonusType) {
        _FreeTrainingBonusType.starter => await _applyStarterBonus(activeBooking, userId),
        _FreeTrainingBonusType.everyFifth => await _applyEveryFifthBonus(activeBooking),
      };
      if (updated == null) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(activeBooking),
          ),
        );
        return true;
      }
      final booking = updated;
      if (bonusType == _FreeTrainingBonusType.starter) {
        await _notifyAdminAboutStarterBonusApplied(booking);
      } else {
        await _notifyAdminAboutEveryFifthBonusApplied(booking);
      }
      await _maybeNotifyGroupAboutCapacity(
        _trainingInfoFromBooking(booking),
        bookingStatus: booking.status,
      );
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        bonusType == _FreeTrainingBonusType.starter
            ? _templates.starterBonusApplied(booking)
            : _templates.everyFifthBonusApplied(booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonCancelBooking) {
      if (userId == null) {
        return false;
      }
      final targetBooking = flowState?.step == _PrivateFlowStep.paymentConfirmation
          ? flowState?.activeBooking
          : await _resolveLatestPendingPaymentBooking(userId);
      if (targetBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final category = _catalogService.categoryForBooking(targetBooking);
      if (!_bookingPolicyService.supportsCancellation(category)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelNotAvailable(targetBooking),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(targetBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(targetBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final cancelResult = await _bookingRepository.cancelBooking(
        userId: userId,
        bookingId: targetBooking.id,
      );
      _flowByUserId.remove(userId);
      if (cancelResult.outcome == BookingActionOutcome.success && cancelResult.booking != null) {
        if (_shouldNotifyAdminAboutBookingCancellation(targetBooking)) {
          await _notifyAdminAboutBookingCancelled(targetBooking);
        }
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelled(cancelResult.booking!),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.bookingNotFound(targetBooking.id),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonSubmitPayment || text.startsWith('/paid'))) {
      if (userId == null) {
        return false;
      }
      if (flowState?.step != _PrivateFlowStep.paymentConfirmation) {
        final opened = await _openPendingPaymentFlow(
          chatId: chatId,
          userId: userId,
        );
        if (!opened) {
          await _sender.sendMessage(
            chatId,
            _templates.noPendingPayment(),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
        }
        return true;
      }
      final activeBooking = flowState?.activeBooking;
      final needsPaymentChoice = activeBooking != null &&
          _shouldShowOutdoorPaymentTypeChoice(activeBooking) &&
          flowState?.paymentChoice == null;
      await _sender.sendMessage(
        chatId,
        needsPaymentChoice
            ? _templates.chooseOutdoorPaymentType()
            : _templates.paymentProofRequired(),
        parseMode: needsPaymentChoice ? 'HTML' : null,
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: flowState?.starterBonusOffered ?? false,
          showCancelBooking: activeBooking != null && _canCancelBookingByPolicy(activeBooking),
          showOutdoorPaymentTypeChoice:
              activeBooking != null && _shouldShowOutdoorPaymentTypeChoice(activeBooking),
        ),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        !text.startsWith('/')) {
      final activeBooking = flowState!.activeBooking;
      final needsPaymentChoice = activeBooking != null &&
          _shouldShowOutdoorPaymentTypeChoice(activeBooking) &&
          flowState.paymentChoice == null;
      await _sender.sendMessage(
        chatId,
        needsPaymentChoice
            ? _templates.chooseOutdoorPaymentType()
            : _templates.paymentProofRequired(),
        parseMode: needsPaymentChoice ? 'HTML' : null,
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: flowState.starterBonusOffered,
          showCancelBooking: activeBooking != null && _canCancelBookingByPolicy(activeBooking),
          showOutdoorPaymentTypeChoice:
              activeBooking != null && _shouldShowOutdoorPaymentTypeChoice(activeBooking),
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonRefreshSchedule || text.startsWith('/refresh_schedule'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.scheduleRefreshForbidden(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final scheduleRefreshOk = await _scheduleRepository.refresh(force: true);
      final trainersRefreshOk = await _trainerDirectoryRepository.refresh(force: true);
      if (!trainersRefreshOk) {
        l.w('Trainer directory refresh failed during /refresh_schedule.');
      }
      final refreshOk = scheduleRefreshOk && trainersRefreshOk;
      await _sendAdminMessage(
        chatId,
        refreshOk ? _templates.scheduleRefreshDone() : _templates.scheduleRefreshFailed(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      await _sendAdminMessage(chatId, _templates.scheduleDocumentLink());
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonPaymentsQueue || text.startsWith('/payments_queue'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingPaymentsQueueCategory,
        availableTrainings: <TrainingInfo>[],
      );
      final counters = await _paymentReviewService.queueCounters();
      await _sendAdminMessage(
        chatId,
        _templates.choosePaymentsQueueCategory(),
        replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
          trainings: counters.trainings,
          yoga: counters.yoga,
          hikes: counters.hikes,
          trails: counters.trails,
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonEconomicSummary || text.startsWith('/economic_summary'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      final range = _parseEconomicSummaryRangeCommand(text);
      if (range != null) {
        await _sendEconomicSummary(chatId: chatId, isAdmin: isAdmin, range: range);
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingEconomicSummaryPeriod,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseEconomicSummaryPeriod(),
        replyMarkup: _templates.economicSummaryPeriodKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingEconomicSummaryPeriod &&
        text != null &&
        !text.startsWith('/')) {
      final range = _parseEconomicSummaryRangeText(text);
      if (range == null) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseEconomicSummaryPeriod(),
          replyMarkup: _templates.economicSummaryPeriodKeyboard(),
        );
        return true;
      }
      _flowByUserId.remove(userId);
      await _sendEconomicSummary(chatId: chatId, isAdmin: isAdmin, range: range);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonParticipantsList ||
            text.startsWith('/participants_list'))) {
      if (!canRunParticipantsAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      if (isYogaTrainer && !canRunAdminAction) {
        _flowByUserId.remove(userId);
        await _sendParticipantsByCategory(
          chatId: chatId,
          category: _ActivityCategory.yoga,
          isAdmin: isAdmin,
          canViewParticipantsList: canRunParticipantsAction,
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingParticipantsCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseParticipantsCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonNoblesList || text.startsWith('/nobles_list'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      await _sendNoblesList(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (text != null && text == MessageTemplates.buttonManageBookings) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseBookingManagementAction(),
        replyMarkup: _templates.adminBookingManagementKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonSubscriptionsAdmin || text.startsWith('/subscriptions'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminSubscriptionsAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseAdminSubscriptionsAction(),
        replyMarkup: _templates.adminSubscriptionsMenuKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminSubscriptionsAction &&
        text != null) {
      if (text == MessageTemplates.buttonSubscriptionsList) {
        _flowByUserId[userId] = flowState!.copyWith(
          step: _PrivateFlowStep.selectingAdminSubscriptionFilter,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionFilterPrompt(),
          replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonSubscribersManagement) {
        await _sendAdminSubscriptionPendingQueue(chatId: chatId);
        return true;
      }
      if (text == MessageTemplates.buttonSubscriptionsSearch) {
        _flowByUserId[userId] = flowState!.copyWith(
          step: _PrivateFlowStep.enteringAdminSubscriptionSearchQuery,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionSearchPrompt(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminSubscriptionFilter &&
        text != null) {
      final filter = switch (text) {
        MessageTemplates.buttonSubscriptionsFilterActive => SubscriptionListFilter.active,
        MessageTemplates.buttonSubscriptionsFilterExpiring => SubscriptionListFilter.expiringSoon,
        MessageTemplates.buttonSubscriptionsFilterPending => SubscriptionListFilter.pending,
        MessageTemplates.buttonSubscriptionsFilterCancelled =>
          SubscriptionListFilter.cancelledOrRejected,
        _ => null,
      };
      if (filter == null) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionFilterPrompt(),
          replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
        );
        return true;
      }
      if (filter == SubscriptionListFilter.pending) {
        await _sendAdminSubscriptionPendingQueue(chatId: chatId);
        return true;
      }
      await _sendAdminSubscriptionsList(chatId: chatId, filter: filter);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminSubscriptionSearchQuery &&
        text != null &&
        !text.startsWith('/')) {
      final items = await _subscriptionRepository.searchSubscriptions(
        text,
        now: _nowProvider(),
      );
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionsList(items, now: _nowProvider()),
        replyMarkup: _templates.adminSubscriptionsMenuKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate &&
        text != null) {
      final reason = switch (text) {
        MessageTemplates.buttonReasonNotConfirmed => 'Чек не подтвержден',
        MessageTemplates.buttonReasonWrongAmount => 'Сумма не совпадает',
        MessageTemplates.buttonReasonDuplicate => 'Дубликат заявки',
        _ => null,
      };
      if (reason == null) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(
            isCancel:
                flowState?.subscriptionModerationAction == SubscriptionModerationAction.cancel,
          ),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.enteringAdminSubscriptionReasonComment,
        subscriptionModerationReason: reason,
      );
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionModerationCommentPrompt(),
        replyMarkup: _templates.subscriptionModerationCommentKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminSubscriptionReasonComment &&
        text != null &&
        !text.startsWith('/')) {
      final action = flowState?.subscriptionModerationAction;
      final requestId = flowState?.subscriptionModerationRequestId;
      final reason = flowState?.subscriptionModerationReason;
      if (action == null || requestId == null || reason == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.chooseAdminSubscriptionsAction(),
          replyMarkup: _templates.adminSubscriptionsMenuKeyboard(),
        );
        return true;
      }
      final comment = text == MessageTemplates.buttonSkipComment
          ? null
          : text.trim().isEmpty
              ? null
              : text;
      await _applySubscriptionModerationAction(
        chatId: chatId,
        requestId: requestId,
        action: action,
        reason: reason,
        comment: comment,
        isAdmin: isAdmin,
      );
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminSubscriptionsAction,
        availableTrainings: <TrainingInfo>[],
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingManagementAction &&
        text != null) {
      if (text == MessageTemplates.buttonBookingsList ||
          text == MessageTemplates.buttonBackToBookingsList) {
        await _openAdminBookingListSegment(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonCreateBooking ||
          text == MessageTemplates.buttonCreateAnotherBooking) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminCreateCategory,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingListSegment &&
        text != null &&
        !text.startsWith('/')) {
      final archived = _parseBookingSegmentSelection(text);
      if (archived == null) {
        final counters = await _bookingRepository.adminCountBySegment();
        await _sendAdminMessage(
          chatId,
          _templates.chooseBookingListSegment(),
          replyMarkup: _templates.bookingSegmentKeyboard(
            activeCount: counters.active,
            archivedCount: counters.archived,
          ),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingListCategory,
        adminViewingArchived: archived,
        selectedCategory: null,
        availableBookings: const <TrainingBooking>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseBookingManagementCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingListCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final archived = flowState?.adminViewingArchived ?? false;
      final listedBookings = await _bookingRepository.adminListBookings(
        category: category,
        archived: archived,
      );
      final now = _nowProvider();
      final bookings = _filterBookingsByArchivedSegment(
        listedBookings,
        archived: archived,
        now: now,
      );
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingFromList,
        selectedCategory: category,
        availableBookings: bookings,
        selectedBooking: null,
        adminBookingsPage: 0,
      );
      await _sendAdminBookingListPage(chatId: chatId, userId: userId);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingFromList &&
        text != null &&
        !text.startsWith('/')) {
      if (text == MessageTemplates.buttonBookingsNextPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage + 1,
        );
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonBookingsPreviousPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage - 1,
        );
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      final selectedBookingId = _parseBookingSelectionId(text);
      final bookings = flowState?.availableBookings ?? const <TrainingBooking>[];
      TrainingBooking? selectedBooking;
      for (final booking in bookings) {
        if (booking.id == selectedBookingId) {
          selectedBooking = booking;
          break;
        }
      }
      if (selectedBooking == null) {
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingAction,
        selectedBooking: selectedBooking,
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingActions(selectedBooking),
        replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonEditBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] =
          flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditField);
      await _sendAdminMessage(
        chatId,
        _templates.chooseAdminBookingEditField(selectedBooking),
        replyMarkup: _templates.adminBookingEditFieldsKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonDeleteBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] =
          flowState!.copyWith(step: _PrivateFlowStep.confirmingAdminBookingDelete);
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingDeleteConfirm(selectedBooking),
        replyMarkup: _templates.adminBookingDeleteConfirmKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingAdminBookingDelete &&
        text != null) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (text == MessageTemplates.buttonCancelDeleteBooking) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingActions(selectedBooking),
          replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
        );
        return true;
      }

      if (text == MessageTemplates.buttonConfirmDeleteBooking) {
        final archived = await _bookingRepository.adminArchiveBooking(selectedBooking.id);
        if (archived == null) {
          await _sendAdminMessage(
            chatId,
            _templates.bookingNotFound(selectedBooking.id),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          _flowByUserId.remove(userId);
          return true;
        }
        await _notifyUserAboutAdminBookingDeleted(archived);
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminBookingManagementAction,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingDeleted(archived),
          replyMarkup: _templates.adminBookingAfterActionKeyboard(),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonRestoreBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (!_canRestoreBooking(selectedBooking)) {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingRestoreNotAllowed(selectedBooking),
          replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
        );
        return true;
      }
      final TrainingBooking? restored;
      try {
        restored = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          status: BookingStatus.pendingPayment,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (restored == null) {
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingRestored(restored),
        replyMarkup: _templates.adminBookingAfterActionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditField &&
        text != null) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingPayment) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditStatus);
        await _sendAdminMessage(
          chatId,
          _templates.chooseAdminBookingPaymentStatus(selectedBooking),
          replyMarkup: _templates.bookingPaymentStatusKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingUsername) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.enteringAdminBookingUsername);
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingAskUsername(selectedBooking),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingEvent) {
        final category = _catalogService.categoryForBooking(selectedBooking);
        final items = _bookableItemsByCategory(category);
        if (items.isEmpty) {
          await _sender.sendMessage(
            chatId,
            _templates.noUpcomingForBooking(),
            replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
          );
          return true;
        }
        _flowByUserId[userId] = flowState!.copyWith(
          step: _PrivateFlowStep.selectingAdminBookingEditEvent,
          availableTrainings: items,
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditStatus &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      final status = _parsePaymentStatusSelection(text);
      if (selectedBooking == null || status == null) {
        await _sendAdminMessage(
          chatId,
          selectedBooking == null
              ? _templates.privateFallback()
              : _templates.chooseAdminBookingPaymentStatus(selectedBooking),
          replyMarkup: selectedBooking == null
              ? _templates.privateMenuKeyboard(isAdmin: isAdmin)
              : _templates.bookingPaymentStatusKeyboard(),
        );
        if (selectedBooking == null) {
          _flowByUserId.remove(userId);
        }
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          status: status,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingPaymentStatusUpdated(updated),
        replyMarkup: _templates.adminBookingAfterActionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminBookingUsername &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final normalizedUsername = _normalizeUsernameInput(text);
      if (normalizedUsername == null) {
        await _sendAdminMessage(
          chatId,
          _templates.invalidUsernameInput(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          userUsername: normalizedUsername,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingUsernameUpdated(updated),
        replyMarkup: _templates.adminBookingAfterActionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditEvent &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final index = _parseTrainingSelectionIndex(text);
      final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
      if (index == null || index < 1 || index > items.length) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          training: items[index - 1],
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBookingEventUpdated(updated),
        replyMarkup: _templates.adminBookingAfterActionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sendAdminMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final items = _bookableItemsByCategory(category);
      if (items.isEmpty) {
        await _sendAdminMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup: _templates.adminBookingManagementKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminCreateEvent,
        availableTrainings: items,
        selectedCategory: category,
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseCreateBookingEvent(items),
        replyMarkup: _templates.bookingSelectionKeyboard(items),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateEvent &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
      if (index == null || index < 1 || index > items.length) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
      final selectedTraining = items[index - 1];
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.enteringAdminCreateUsername,
        adminCreateTraining: selectedTraining,
      );
      await _sendAdminMessage(
        chatId,
        _templates.createBookingAskUsername(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminCreateUsername &&
        text != null &&
        !text.startsWith('/')) {
      final normalizedUsername = _normalizeUsernameInput(text);
      if (normalizedUsername == null) {
        await _sendAdminMessage(
          chatId,
          _templates.invalidUsernameInput(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminCreateStatus,
        adminCreateUsername: normalizedUsername,
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseCreateBookingPaymentStatus(),
        replyMarkup: _templates.bookingPaymentStatusKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateStatus &&
        text != null &&
        !text.startsWith('/')) {
      final status = _parsePaymentStatusSelection(text);
      final training = flowState?.adminCreateTraining;
      final username = flowState?.adminCreateUsername;
      if (status == null || training == null || username == null) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingPaymentStatus(),
          replyMarkup: _templates.bookingPaymentStatusKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.confirmingAdminCreate,
        adminCreateStatus: status,
      );
      await _sendAdminMessage(
        chatId,
        _templates.createBookingPreview(training: training, username: username, status: status),
        replyMarkup: _templates.adminCreateBookingConfirmationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingAdminCreate &&
        text != null) {
      if (text == MessageTemplates.buttonCancelCreateBooking) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminBookingManagementAction,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseBookingManagementAction(),
          replyMarkup: _templates.adminBookingManagementKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonConfirmCreateBooking) {
        final training = flowState?.adminCreateTraining;
        final username = flowState?.adminCreateUsername;
        final status = flowState?.adminCreateStatus;
        if (training == null || username == null || status == null) {
          await _sender.sendMessage(
            chatId,
            _templates.privateFallback(),
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          _flowByUserId.remove(userId);
          return true;
        }
        final created = await _bookingRepository.adminCreateBooking(
          userUsername: username,
          training: training,
          status: status,
        );
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminBookingManagementAction,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingCreated(created),
          replyMarkup: _templates.adminBookingAfterActionKeyboard(),
        );
        return true;
      }
    }

    if (text != null &&
        (text.startsWith('/approve_payment') ||
            text.startsWith('/approve_partial_payment') ||
            text.startsWith('/reject_payment'))) {
      if (!isAdmin) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        await _sendAdminMessage(
          chatId,
          _templates.paymentActionUsage(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final status = switch (true) {
        _ when text.startsWith('/approve_partial_payment') => BookingStatus.partialPaid,
        _ when text.startsWith('/approve_payment') => BookingStatus.paid,
        _ => BookingStatus.paymentRejected,
      };
      final reviewResult = await _bookingRepository.reviewSubmittedPayment(
        bookingId: bookingId,
        status: status,
      );
      final booking = reviewResult.booking;
      final queueCounters = await _paymentReviewService.queueCounters();
      if (reviewResult.outcome == PaymentReviewOutcome.success && booking != null) {
        await _notifyAboutPaymentReview(
          booking,
          moderatorUserId: userId,
          moderatorUsername: context.from?['username']?.toString(),
        );
        await _maybeNotifyGroupAboutCapacity(
          _trainingInfoFromBooking(booking),
          bookingStatus: booking.status,
        );
      }
      await _sendAdminMessage(
        chatId,
        switch (reviewResult.outcome) {
          PaymentReviewOutcome.success => _templates.paymentReviewResultWithNextStep(
              booking: booking!,
              remaining: queueCounters.total,
            ),
          PaymentReviewOutcome.notFound => _templates.bookingNotFound(bookingId),
          PaymentReviewOutcome.invalidStatus => _templates.paymentAlreadyReviewed(bookingId),
        },
        replyMarkup: reviewResult.outcome == PaymentReviewOutcome.success
            ? _templates.openPaymentsQueueInlineKeyboard(total: queueCounters.total)
            : _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text.startsWith('/approve_subscription') ||
            text.startsWith('/reject_subscription') ||
            text.startsWith('/cancel_subscription'))) {
      if (!isAdmin) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final requestId = _updateRouter.parseCommandId(text);
      if (requestId == null) {
        await _sendAdminMessage(
          chatId,
          'Используй команды:\n'
          '<code>/approve_subscription &lt;id&gt;</code>\n'
          '<code>/reject_subscription &lt;id&gt;</code>\n'
          '<code>/cancel_subscription &lt;id&gt;</code>',
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      if (text.startsWith('/cancel_subscription')) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate,
          availableTrainings: const <TrainingInfo>[],
          subscriptionModerationAction: SubscriptionModerationAction.cancel,
          subscriptionModerationRequestId: requestId,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(isCancel: true),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      if (text.startsWith('/reject_subscription')) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate,
          availableTrainings: const <TrainingInfo>[],
          subscriptionModerationAction: SubscriptionModerationAction.reject,
          subscriptionModerationRequestId: requestId,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(isCancel: false),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      await _applySubscriptionModerationAction(
        chatId: chatId,
        requestId: requestId,
        action: SubscriptionModerationAction.reject,
        approveDirectly: true,
        reason: null,
        comment: null,
        isAdmin: isAdmin,
      );
      return true;
    }

    await _sender.sendMessage(
      chatId,
      _templates.privateFallback(),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
    );
    return true;
  }

  String _scheduleTextByCategory(_ActivityCategory category) {
    return _scheduleQueryService.scheduleText(category);
  }

  Future<void> _refreshTrainerDirectoryForSchedule() async {
    final refreshOk = await _trainerDirectoryRepository.refresh();
    if (!refreshOk) {
      l.w('Trainer directory refresh failed before schedule rendering. Using cached trainers.');
    }
  }

  List<TrainingInfo> _bookableItemsByCategory(_ActivityCategory category) {
    return _catalogService.bookableItems(category);
  }

  Future<void> _sendParticipantsByCategory({
    required int chatId,
    required _ActivityCategory category,
    required bool isAdmin,
    required bool canViewParticipantsList,
  }) async {
    final trainings = _participantItemsByCategory(category);
    final activeBookings = await _bookingRepository.adminListBookings(
      category: category,
      archived: false,
      limit: 500,
    );
    final archivedBookings = await _bookingRepository.adminListBookings(
      category: category,
      archived: true,
      limit: 500,
    );
    final segmentBookings = <TrainingBooking>[
      ...activeBookings,
      ...archivedBookings,
    ];
    final trainingsByKey = <String, TrainingInfo>{
      for (final training in trainings) training.sessionKey: training,
    };
    final scheduleBySignature = <String, List<TrainingInfo>>{};
    for (final training in trainings) {
      scheduleBySignature
          .putIfAbsent(_trainingSignature(training), () => <TrainingInfo>[])
          .add(training);
    }
    for (final candidates in scheduleBySignature.values) {
      candidates.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    }
    for (final booking in segmentBookings) {
      final targetTrainingKey = _resolveParticipantsTrainingKey(
        booking: booking,
        trainingsByKey: trainingsByKey,
        trainingsBySignature: scheduleBySignature,
      );
      if (targetTrainingKey != booking.trainingKey ||
          trainingsByKey.containsKey(booking.trainingKey)) {
        continue;
      }
      trainingsByKey.putIfAbsent(
        booking.trainingKey,
        () => TrainingInfo(
          title: booking.trainingTitle,
          startsAt: booking.startsAt,
          location: booking.location,
          category: category,
        ),
      );
    }
    final mergedTrainings = trainingsByKey.values.toList(growable: false)
      ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
    final now = _nowProvider();
    final visibleTrainings = mergedTrainings
        .where((training) => !_isArchivedTrainingAt(training, now: now))
        .toList(growable: false);
    final queryKeys = <String>{
      ...trainingsByKey.keys,
      ...segmentBookings.map((booking) => booking.trainingKey),
    };
    final bookings = queryKeys.isEmpty
        ? const <TrainingBooking>[]
        : await _bookingRepository.listByTrainingKeys(
            queryKeys,
            limit: 1000,
            includeCancelled: true,
          );
    final byTraining = <String, List<TrainingBooking>>{};
    for (final booking in bookings) {
      final targetTrainingKey = _resolveParticipantsTrainingKey(
        booking: booking,
        trainingsByKey: trainingsByKey,
        trainingsBySignature: scheduleBySignature,
      );
      byTraining.putIfAbsent(targetTrainingKey, () => <TrainingBooking>[]).add(booking);
    }
    final normalizedByTraining = <String, List<TrainingBooking>>{};
    for (final entry in byTraining.entries) {
      normalizedByTraining[entry.key] = _deduplicateParticipantBookings(entry.value);
    }

    final copy = _scheduleHandler.participantsCopy(category);

    await _sendAdminMessage(
      chatId,
      _templates.trainingParticipants(
        trainings: visibleTrainings,
        bookingsByTrainingKey: normalizedByTraining,
        title: copy.title,
        emptyText: copy.emptyText,
        isTrainerBooking: _isWhitelistedTrainerBookingByBooking,
      ),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        canViewParticipantsList: canViewParticipantsList,
      ),
    );
  }

  String _resolveParticipantsTrainingKey({
    required TrainingBooking booking,
    required Map<String, TrainingInfo> trainingsByKey,
    required Map<String, List<TrainingInfo>> trainingsBySignature,
  }) {
    if (trainingsByKey.containsKey(booking.trainingKey)) {
      return booking.trainingKey;
    }
    final candidates = trainingsBySignature[_bookingSignature(booking)];
    if (candidates == null || candidates.isEmpty) {
      return booking.trainingKey;
    }
    final candidate = _nearestTrainingByStartsAt(candidates, booking.startsAt);
    final dayDistance = (candidate.startsAt.difference(booking.startsAt).inHours).abs();
    if (dayDistance > 24 * 21) {
      return booking.trainingKey;
    }
    return candidate.sessionKey;
  }

  TrainingInfo _nearestTrainingByStartsAt(
    List<TrainingInfo> candidates,
    DateTime target,
  ) {
    var best = candidates.first;
    var bestDistance = (best.startsAt.difference(target).inMinutes).abs();
    for (var index = 1; index < candidates.length; index++) {
      final candidate = candidates[index];
      final distance = (candidate.startsAt.difference(target).inMinutes).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  List<TrainingBooking> _deduplicateParticipantBookings(List<TrainingBooking> bookings) {
    if (bookings.length < 2) {
      return bookings;
    }
    final bestByIdentity = <String, TrainingBooking>{};
    for (final booking in bookings) {
      final identity = _participantIdentity(booking);
      final existing = bestByIdentity[identity];
      if (existing == null) {
        bestByIdentity[identity] = booking;
        continue;
      }
      if (_shouldReplaceParticipant(existing: existing, candidate: booking)) {
        bestByIdentity[identity] = booking;
      }
    }
    final deduplicated = bestByIdentity.values.toList(growable: false)
      ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    return deduplicated;
  }

  bool _shouldReplaceParticipant({
    required TrainingBooking existing,
    required TrainingBooking candidate,
  }) {
    final existingCancelled = existing.status == BookingStatus.cancelled;
    final candidateCancelled = candidate.status == BookingStatus.cancelled;
    if (existingCancelled && !candidateCancelled) {
      return true;
    }
    if (!existingCancelled && candidateCancelled) {
      return false;
    }
    return candidate.updatedAt.isAfter(existing.updatedAt);
  }

  String _participantIdentity(TrainingBooking booking) {
    if (booking.userId > 0) {
      return 'id:${booking.userId}';
    }
    final username = booking.userUsername?.trim().toLowerCase();
    if (username != null && username.isNotEmpty) {
      return 'username:$username';
    }
    return 'id:${booking.userId}';
  }

  String _trainingSignature(TrainingInfo training) {
    return '${training.title.trim().toLowerCase()}|${training.location.trim().toLowerCase()}';
  }

  String _bookingSignature(TrainingBooking booking) {
    return '${booking.trainingTitle.trim().toLowerCase()}|${booking.location.trim().toLowerCase()}';
  }

  Future<void> _sendPaymentsQueueByCategory({
    required int chatId,
    required _ActivityCategory category,
    required bool isAdmin,
  }) async {
    final filtered = await _paymentReviewService.queueByCategory(category);
    if (filtered.isEmpty) {
      await _sender.sendMessage(
        chatId,
        _templates.paymentsQueueEmpty(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return;
    }

    await _sendAdminMessage(
      chatId,
      _templates.paymentsQueueIntro(filtered.length, category: category),
    );
    for (final booking in filtered) {
      final proofChatId = booking.paymentProofChatId;
      final proofMessageId = booking.paymentProofMessageId;
      if (proofChatId != null && proofMessageId != null) {
        try {
          await _sender.copyMessage(
            chatId,
            fromChatId: proofChatId,
            messageId: proofMessageId,
          );
        } on Object catch (error, stackTrace) {
          l.w('Failed to copy payment proof for booking ${booking.id}: $error', stackTrace);
          await _sendAdminMessage(
            chatId,
            _templates.paymentProofUnavailableHint(booking),
          );
        }
      }
      await _sendAdminMessage(
        chatId,
        _templates.paymentsQueueItem(booking),
        replyMarkup: _templates.paymentDecisionInlineKeyboard(
          booking.id,
          approvePartial: _hasPartialPaymentChoice(booking.paymentNote),
        ),
      );
    }
  }

  Future<void> _sendNoblesList({
    required int chatId,
    required bool isAdmin,
  }) async {
    final result = await _noblesListService.buildStats();
    await _sendAdminMessage(
      chatId,
      _templates.noblesList(result.users, totalTrainings: result.totalTrainings),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
    );
  }

  Future<void> _sendEconomicSummary({
    required int chatId,
    required bool isAdmin,
    required _EconomicSummaryRange range,
  }) async {
    final now = _nowProvider();
    final period = switch (range) {
      _EconomicSummaryRange.currentWeek => _economicSummaryService.currentWeeklyPeriod(now),
      _EconomicSummaryRange.previousWeek =>
        _economicSummaryService.latestCompletedWeeklyPeriod(now),
      _EconomicSummaryRange.currentMonth => _economicSummaryService.currentMonthlyPeriod(now),
      _EconomicSummaryRange.previousMonth =>
        _economicSummaryService.latestCompletedMonthlyPeriod(now),
    };
    final summary = await _economicSummaryService.buildSummary(period);
    await _sendAdminMessage(
      chatId,
      _templates.economicSummary(summary, periodLabel: range.label),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
    );
  }

  Future<void> _createOrContinueBooking({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required _PrivateFlowState flowState,
    required TrainingInfo selectedTraining,
    required String? username,
    required Map<String, Object?> onParticipantsLimitReplyMarkup,
  }) async {
    late final BookingCreateResult result;
    try {
      result = await _bookingRepository.createPendingBooking(
        userId: userId,
        userUsername: username,
        training: selectedTraining,
      );
    } on BookingParticipantsLimitExceededException {
      await _sender.sendMessage(
        chatId,
        _templates.bookingParticipantsLimitExceeded(),
        replyMarkup: onParticipantsLimitReplyMarkup,
      );
      return;
    }
    if (_isFreeActivity(selectedTraining)) {
      final paidBooking =
          await _bookingRepository.updateStatus(result.booking.id, BookingStatus.paid);
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
        await _notifyAdminAboutFreeBookingCreated(bookingForResponse);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedWithoutPayment(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        parseMode: 'HTML',
      );
      return;
    }
    if (_isWhitelistedTrainerBooking(userId: userId, username: username)) {
      final paidBooking =
          await _bookingRepository.updateStatus(result.booking.id, BookingStatus.paid);
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      _flowByUserId.remove(userId);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
      }
      await _notifyAdminAboutTrainerBookingCreated(bookingForResponse);
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedForWhitelistedTrainer(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        parseMode: 'HTML',
      );
      return;
    }
    final proIncludedAvailable = await _hasProIncludedTrainingAvailable(
      userId: userId,
      training: selectedTraining,
      booking: result.booking,
    );
    if (proIncludedAvailable) {
      final paidBooking = await _bookingRepository.updateStatus(
        result.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
      );
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      _flowByUserId.remove(userId);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
      }
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedWithoutPayment(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        parseMode: 'HTML',
      );
      return;
    }
    final starterBonusOffered = selectedTraining.category == _ActivityCategory.trainings &&
        await _hasAnyFreeTrainingBonusAvailable(userId);
    _flowByUserId[userId] = flowState.copyWith(
      step: _PrivateFlowStep.paymentConfirmation,
      activeBooking: result.booking,
      starterBonusOffered: starterBonusOffered,
      paymentChoice: null,
    );
    if (result.created && MessageFormatters.isOutdoorBooking(result.booking)) {
      await _sender.sendMessage(
        chatId,
        _templates.outdoorBookingRule(result.booking),
        parseMode: 'HTML',
      );
    }
    await _sender.sendMessage(
      chatId,
      result.created
          ? _templates.bookingCreated(result.booking)
          : _templates.bookingAlreadyExists(result.booking),
      replyMarkup: _templates.paymentConfirmationKeyboard(
        showStarterBonus: starterBonusOffered,
        showCancelBooking: _canCancelBookingByPolicy(result.booking),
        showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(result.booking),
      ),
      parseMode: 'HTML',
    );
  }

  Future<void> _openBookingByCategory({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required _ActivityCategory category,
    required bool fromSchedulePreview,
  }) async {
    final upcoming = _bookableItemsByCategory(category);
    if (upcoming.isEmpty) {
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.noUpcomingForBooking(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return;
    }
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingTraining,
      availableTrainings: upcoming,
      selectedCategory: category,
      bookingFromSchedulePreview: fromSchedulePreview,
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseTrainingForBooking(upcoming),
      replyMarkup: _templates.bookingSelectionKeyboard(upcoming),
    );
  }

  List<TrainingInfo> _participantItemsByCategory(_ActivityCategory category) {
    return _catalogService.participantItems(category);
  }

  _ActivityCategory? _parseCategory(String text) {
    return _catalogService.parseCategory(text);
  }

  int? _parseTrainingSelectionIndex(String text) {
    return _updateRouter.parseTrainingSelectionIndex(text);
  }

  int? _parseBookingSelectionId(String text) {
    return _updateRouter.parseBookingIdSelection(text);
  }

  int? _parseTrainerSelectionIndex(String text) {
    final match = RegExp(r'(\d+)\.').firstMatch(text);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  bool? _parseBookingSegmentSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('актив')) {
      return false;
    }
    if (normalized.contains('архив')) {
      return true;
    }
    return null;
  }

  bool? _parseMyBookingSegmentSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('актуал')) {
      return false;
    }
    if (normalized.contains('прошед')) {
      return true;
    }
    return null;
  }

  BookingStatus? _parsePaymentStatusSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('ожидает')) {
      return BookingStatus.pendingPayment;
    }
    if (normalized.contains('проверке') || normalized.contains('проверк')) {
      return BookingStatus.paymentSubmitted;
    }
    if (normalized.contains('предоплат') ||
        normalized.contains('аванс') ||
        normalized.contains('задат')) {
      return BookingStatus.partialPaid;
    }
    if (normalized.contains('оплачен') || normalized.contains('оплачено')) {
      return BookingStatus.paid;
    }
    if (normalized.contains('бесплат')) {
      return BookingStatus.freeTraining;
    }
    if (normalized.contains('отклон')) {
      return BookingStatus.paymentRejected;
    }
    return null;
  }

  String? _normalizeUsernameInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  Future<void> _openMyBookingListSegment({
    required int chatId,
    required int userId,
  }) async {
    final bookings = await _bookingRepository.listUserBookings(userId);
    if (bookings.isEmpty) {
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        'У тебя пока нет записей на мероприятия 🙃',
        replyMarkup: _templates.profileActionsKeyboard(),
      );
      return;
    }
    final now = _nowProvider();
    final currentCount =
        bookings.where((booking) => !_isArchivedBookingAt(booking, now: now)).length;
    final pastCount = bookings.length - currentCount;
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingBookingListSegment,
      availableTrainings: const <TrainingInfo>[],
      availableBookings: bookings,
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseMyBookingsSegment(),
      replyMarkup: _templates.myBookingSegmentKeyboard(
        currentCount: currentCount,
        pastCount: pastCount,
      ),
      parseMode: 'HTML',
    );
  }

  Future<void> _sendMyBookingListPage({
    required int chatId,
    required int userId,
  }) async {
    final flowState = _flowByUserId[userId];
    if (flowState == null || flowState.step != _PrivateFlowStep.selectingBookingToManage) {
      return;
    }
    final now = _nowProvider();
    final allBookings = _filterBookingsByArchivedSegment(
      flowState.availableBookings,
      archived: flowState.adminViewingArchived,
      now: now,
    );
    final maxPage = _maxMyBookingsPage(allBookings);
    final page = flowState.adminBookingsPage.clamp(0, maxPage);
    final start = page * _myBookingsPageSize;
    final end = (start + _myBookingsPageSize).clamp(0, allBookings.length);
    final pageBookings = allBookings.sublist(start, end);
    _flowByUserId[userId] = flowState.copyWith(
      adminBookingsPage: page,
      availableBookings: allBookings,
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseMyBookingFromList(
        pageBookings,
        past: flowState.adminViewingArchived,
        page: page + 1,
        totalPages: maxPage + 1,
        totalCount: allBookings.length,
      ),
      replyMarkup: allBookings.isEmpty
          ? _templates.myBookingSegmentKeyboard(currentCount: 0, pastCount: 0)
          : _templates.myBookingSelectionKeyboard(
              pageBookings,
              hasPreviousPage: page > 0,
              hasNextPage: page < maxPage,
            ),
      parseMode: 'HTML',
    );
  }

  int _maxMyBookingsPage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 0;
    }
    return (bookings.length - 1) ~/ _myBookingsPageSize;
  }

  Future<void> _openAdminBookingListSegment({
    required int chatId,
    required int userId,
  }) async {
    final counters = await _bookingRepository.adminCountBySegment();
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.selectingAdminBookingListSegment,
      availableTrainings: <TrainingInfo>[],
    );
    await _sendAdminMessage(
      chatId,
      _templates.chooseBookingListSegment(),
      replyMarkup: _templates.bookingSegmentKeyboard(
        activeCount: counters.active,
        archivedCount: counters.archived,
      ),
    );
  }

  Future<void> _sendAdminBookingListPage({
    required int chatId,
    required int userId,
  }) async {
    final flowState = _flowByUserId[userId];
    if (flowState == null || flowState.step != _PrivateFlowStep.selectingAdminBookingFromList) {
      return;
    }
    final now = _nowProvider();
    final allBookings = _filterBookingsByArchivedSegment(
      flowState.availableBookings,
      archived: flowState.adminViewingArchived,
      now: now,
    );
    final maxPage = _maxAdminBookingsPage(allBookings);
    final page = flowState.adminBookingsPage.clamp(0, maxPage);
    final start = page * _adminBookingsPageSize;
    final end = (start + _adminBookingsPageSize).clamp(0, allBookings.length);
    final pageBookings = allBookings.sublist(start, end);
    _flowByUserId[userId] =
        flowState.copyWith(adminBookingsPage: page, availableBookings: allBookings);
    await _sendAdminMessage(
      chatId,
      _templates.chooseAdminBookingFromList(
        pageBookings,
        archived: flowState.adminViewingArchived,
        category: flowState.selectedCategory,
        page: page + 1,
        totalPages: maxPage + 1,
        totalCount: allBookings.length,
      ),
      replyMarkup: allBookings.isEmpty
          ? _templates.adminBookingManagementKeyboard()
          : _templates.adminBookingSelectionKeyboard(
              pageBookings,
              hasPreviousPage: page > 0,
              hasNextPage: page < maxPage,
            ),
    );
  }

  int _maxAdminBookingsPage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 0;
    }
    return (bookings.length - 1) ~/ _adminBookingsPageSize;
  }

  List<TrainingBooking> _filterBookingsByArchivedSegment(
    List<TrainingBooking> bookings, {
    required bool archived,
    required DateTime now,
  }) {
    return bookings
        .where(
          (booking) => archived == _isArchivedBookingAt(booking, now: now),
        )
        .toList(growable: false);
  }

  bool _isArchivedBookingAt(TrainingBooking booking, {required DateTime now}) {
    return booking.startsAt.isBefore(now) || booking.status == BookingStatus.cancelled;
  }

  bool _isArchivedTrainingAt(TrainingInfo training, {required DateTime now}) {
    return training.startsAt.isBefore(now);
  }

  bool _isOutdoorCategory(_ActivityCategory category) {
    return _bookingPolicyService.isOutdoorCategory(category);
  }

  Map<String, Object?> _bookingActionsKeyboard(TrainingBooking booking) {
    return _templates.bookingActionsKeyboard(
      canReschedule: _bookingPolicyService.canReschedule(booking),
      canCancel: _canCancelBookingByPolicy(booking),
      canRepeat: true,
      canCompletePayment: booking.status == BookingStatus.partialPaid,
    );
  }

  Map<String, Object?> _adminBookingActionsKeyboard(TrainingBooking booking) {
    return _templates.adminBookingActionsKeyboard(canRestore: _canRestoreBooking(booking));
  }

  bool _canRestoreBooking(TrainingBooking booking) {
    if (booking.status != BookingStatus.cancelled) {
      return false;
    }
    return booking.startsAt.isAfter(_nowProvider());
  }

  Future<int> _sendAdminMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
  }) {
    return _sender.sendMessage(
      chatId,
      text,
      disableNotification: disableNotification,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup,
      parseMode: 'HTML',
    );
  }

  Future<void> _sendAdminSubscriptionsList({
    required int chatId,
    SubscriptionListFilter filter = SubscriptionListFilter.active,
  }) async {
    final now = _nowProvider();
    final active = await _subscriptionRepository.listSubscriptionsByFilter(
      filter: filter,
      now: now,
      limit: 200,
    );
    await _sendAdminMessage(
      chatId,
      _templates.subscriptionsList(active, now: now),
      replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
    );
    for (final request in active) {
      if (filter == SubscriptionListFilter.active ||
          filter == SubscriptionListFilter.expiringSoon) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionActiveItem(request),
          replyMarkup: _templates.subscriptionCancelInlineKeyboard(request.id),
        );
        continue;
      }
      final until = request.activeUntil == null ? '—' : request.activeUntil!.toIso8601String();
      final reason = request.moderationReason?.trim();
      final comment = request.moderationComment?.trim();
      await _sendAdminMessage(
        chatId,
        '🧾 <b>Абонемент #${request.id}</b>\n'
        'Пользователь: ${request.userId}\n'
        'Статус: <b>${request.status.dbValue}</b>\n'
        'До: $until'
        '${(reason ?? '').isEmpty ? '' : '\nПричина: $reason'}'
        '${(comment ?? '').isEmpty ? '' : '\nКомментарий: $comment'}',
      );
    }
  }

  Future<void> _sendAdminSubscriptionPendingQueue({
    required int chatId,
  }) async {
    final queue = await _subscriptionRepository.listPendingRequests(limit: 200);
    if (queue.isEmpty) {
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionPendingQueueEmpty(),
        replyMarkup: _templates.adminSubscriptionsMenuKeyboard(),
      );
      return;
    }
    await _sendAdminMessage(
      chatId,
      _templates.subscriptionPendingQueueIntro(queue.length),
      replyMarkup: _templates.adminSubscriptionsMenuKeyboard(),
    );
    for (final request in queue) {
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionPendingQueueItem(request),
        replyMarkup: _templates.subscriptionDecisionInlineKeyboard(request.id),
      );
      final proofChatId = request.paymentProofChatId;
      final proofMessageId = request.paymentProofMessageId;
      if (proofChatId == null || proofMessageId == null) {
        continue;
      }
      try {
        await _sender.copyMessage(
          chatId,
          fromChatId: proofChatId,
          messageId: proofMessageId,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to copy subscription proof for request #${request.id}: $error', stackTrace);
      }
    }
  }

  Future<void> _notifyAdminAboutPaymentSubmitted(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      final counters = await _paymentReviewService.queueCounters();
      await _sendAdminMessage(
        adminChatId,
        _templates.paymentSubmittedAdminNotification(booking),
        replyMarkup: _templates.openPaymentsQueueInlineKeyboard(total: counters.total),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment submission: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutSubscriptionSubmitted(SubscriptionRequest request) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.subscriptionPendingQueueItem(request),
        replyMarkup: _templates.subscriptionDecisionInlineKeyboard(request.id),
      );
      final proofChatId = request.paymentProofChatId;
      final proofMessageId = request.paymentProofMessageId;
      if (proofChatId != null && proofMessageId != null) {
        await _sender.copyMessage(
          adminChatId,
          fromChatId: proofChatId,
          messageId: proofMessageId,
        );
      }
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about subscription request: $error', stackTrace);
    }
  }

  Future<void> _applySubscriptionModerationAction({
    required int chatId,
    required int requestId,
    required SubscriptionModerationAction action,
    required bool isAdmin,
    bool approveDirectly = false,
    String? reason,
    String? comment,
  }) async {
    if (approveDirectly) {
      final review = await _subscriptionRepository.reviewPendingRequestWithReason(
        requestId: requestId,
        approve: true,
        reviewedAt: _nowProvider(),
      );
      final remaining = (await _subscriptionRepository.listPendingRequests(limit: 500)).length;
      await _sendAdminMessage(
        chatId,
        switch (review.outcome) {
          ReviewSubscriptionRequestOutcome.success =>
            _templates.subscriptionReviewResultWithNextStep(
              request: review.request!,
              remaining: remaining,
            ),
          ReviewSubscriptionRequestOutcome.notFound => '😕 <b>Заявка #$requestId не найдена</b>',
          ReviewSubscriptionRequestOutcome.invalidStatus =>
            'ℹ️ <b>Заявка #$requestId уже обработана</b>',
        },
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      if (review.outcome == ReviewSubscriptionRequestOutcome.success && review.request != null) {
        await _notifyUserAboutSubscriptionDecision(review.request!);
      }
      return;
    }

    if (action == SubscriptionModerationAction.reject) {
      final review = await _subscriptionRepository.reviewPendingRequestWithReason(
        requestId: requestId,
        approve: false,
        reviewedAt: _nowProvider(),
        reason: reason,
        comment: comment,
      );
      final remaining = (await _subscriptionRepository.listPendingRequests(limit: 500)).length;
      await _sendAdminMessage(
        chatId,
        switch (review.outcome) {
          ReviewSubscriptionRequestOutcome.success =>
            _templates.subscriptionReviewResultWithNextStep(
              request: review.request!,
              remaining: remaining,
            ),
          ReviewSubscriptionRequestOutcome.notFound => '😕 <b>Заявка #$requestId не найдена</b>',
          ReviewSubscriptionRequestOutcome.invalidStatus =>
            'ℹ️ <b>Заявка #$requestId уже обработана</b>',
        },
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      if (review.outcome == ReviewSubscriptionRequestOutcome.success && review.request != null) {
        await _notifyUserAboutSubscriptionDecision(review.request!);
      }
      return;
    }

    final cancelResult = await _subscriptionRepository.cancelActiveSubscription(
      requestId: requestId,
      cancelledAt: _nowProvider(),
      reason: reason,
      comment: comment,
    );
    await _sendAdminMessage(
      chatId,
      switch (cancelResult.outcome) {
        CancelSubscriptionOutcome.success =>
          _templates.subscriptionCancelResult(cancelResult.request!),
        CancelSubscriptionOutcome.notFound => '😕 <b>Абонемент #$requestId не найден</b>',
        CancelSubscriptionOutcome.invalidStatus => 'ℹ️ <b>Абонемент #$requestId уже не активен</b>',
      },
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
    );
    if (cancelResult.outcome == CancelSubscriptionOutcome.success && cancelResult.request != null) {
      try {
        await _sender.sendMessage(
          cancelResult.request!.userId,
          _templates.subscriptionCancelledForUser(
            reason: reason,
            comment: comment,
          ),
          parseMode: 'HTML',
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to notify user about subscription cancel: $error', stackTrace);
      }
    }
  }

  Future<void> _notifyUserAboutSubscriptionDecision(SubscriptionRequest request) async {
    try {
      if (request.status == SubscriptionRequestStatus.active) {
        await _sender.sendMessage(
          request.userId,
          _templates.subscriptionApprovedForUser(
            activeUntil: request.activeUntil ?? _nowProvider(),
          ),
          parseMode: 'HTML',
        );
        return;
      }
      await _sender.sendMessage(
        request.userId,
        _templates.subscriptionRejectedForUser(
          reason: request.moderationReason,
          comment: request.moderationComment,
        ),
        parseMode: 'HTML',
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about subscription review: $error', stackTrace);
    }
  }

  Future<void> _notifyAboutPaymentReview(
    TrainingBooking booking, {
    required int? moderatorUserId,
    String? moderatorUsername,
  }) async {
    try {
      final isApproved =
          booking.status == BookingStatus.paid || booking.status == BookingStatus.partialPaid;
      await _sender.sendMessage(
        booking.userId,
        isApproved
            ? _templates.paymentApprovedForUser(booking)
            : _templates.paymentRejectedForUser(booking),
      );
      if (isApproved) {
        final outdoorItem = _catalogService.outdoorByBooking(booking);
        if (outdoorItem != null) {
          await _sender.sendMessage(
            booking.userId,
            _templates.outdoorItineraryDetails(outdoorItem),
            parseMode: 'HTML',
          );
          await _sender.sendMessage(
            booking.userId,
            _templates.outdoorEquipmentDetails(outdoorItem),
            parseMode: 'HTML',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about payment review: $error', stackTrace);
    }

    final adminChatId = _adminChatId;
    if (adminChatId == null || moderatorUserId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.paymentReviewAdminNotification(
          booking: booking,
          moderatorUserId: moderatorUserId,
          moderatorUsername: moderatorUsername,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment review: $error', stackTrace);
    }
  }

  Future<void> _handleStartCleanup(int userId) async {
    try {
      final welcome = await _onboardingRepository.markStartedAndGetPendingWelcome(
        userId,
        startedAt: _nowProvider(),
      );
      if (welcome == null) {
        return;
      }
      await _sender.deleteMessage(
        welcome.groupChatId,
        messageId: welcome.welcomeMessageId,
      );
      await _onboardingRepository.markWelcomeDeleted(
        userId: userId,
        deletedAt: _nowProvider(),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to cleanup group welcome on /start for user $userId: $error', stackTrace);
    }
  }

  Future<void> _tryPinWelcomeMessage({
    required int chatId,
    required int messageId,
  }) async {
    try {
      await _sender.pinMessage(chatId, messageId: messageId);
    } on Object catch (error, stackTrace) {
      l.w(
        'Failed to pin welcome message in private chat $chatId (message_id=$messageId): $error',
        stackTrace,
      );
    }
  }

  bool _isIgnorableServiceMessage(Map<String, dynamic>? message) {
    if (message == null) {
      return false;
    }
    // Telegram sends a service update after pinning; it should not trigger fallback.
    return message['pinned_message'] is Map;
  }

  Future<void> _notifyAdminAboutStarterBonusApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.starterBonusAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about starter bonus booking: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutEveryFifthBonusApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.everyFifthBonusAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about every-fifth bonus booking: $error', stackTrace);
    }
  }

  Future<bool> _hasAnyFreeTrainingBonusAvailable(int userId) async {
    final starterAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    if (starterAvailable) {
      return true;
    }
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    return progress.availableRewardsCount > 0;
  }

  Future<bool> _hasProIncludedTrainingAvailable({
    required int userId,
    required TrainingInfo training,
    required TrainingBooking booking,
  }) async {
    if (training.category != ActivityCategory.trainings) {
      return false;
    }
    if (_isFreeActivity(training)) {
      return false;
    }
    if (booking.status != BookingStatus.pendingPayment) {
      return false;
    }
    final now = _nowProvider();
    final membership = await _subscriptionRepository.getMembership(userId, now: now);
    final remaining = await _proIncludedTrainingRemainingCount(
      userId: userId,
      membership: membership,
    );
    return (remaining ?? 0) > 0;
  }

  Future<int?> _proIncludedTrainingRemainingCount({
    required int userId,
    required SubscriptionMembership membership,
  }) async {
    final activeUntil = membership.activeUntil;
    if (membership.level != MembershipLevel.pro || activeUntil == null) {
      return null;
    }
    final periodStart = activeUntil.subtract(const Duration(days: 30));
    final paidBookings = await _bookingRepository.listPaidBookingsInRange(
      fromInclusive: periodStart,
      toExclusive: activeUntil.add(const Duration(seconds: 1)),
    );
    final usedIncludedTrainings = paidBookings
        .where(
          (item) =>
              item.userId == userId &&
              item.paymentNote == MessageFormatters.proIncludedTrainingPaymentNoteMarker,
        )
        .length;
    final remaining = _proIncludedTrainingsPerPeriod - usedIncludedTrainings;
    return remaining < 0 ? 0 : remaining;
  }

  bool _isFreeActivity(TrainingInfo training) {
    final price = training.price;
    return price != null && price <= 0;
  }

  TrainingBooking _bookingWithStatus(
    TrainingBooking fallback,
    BookingStatus status,
    TrainingBooking? candidate,
  ) {
    if (candidate != null) {
      return candidate;
    }
    return TrainingBooking(
      id: fallback.id,
      userId: fallback.userId,
      userUsername: fallback.userUsername,
      trainingKey: fallback.trainingKey,
      trainingTitle: fallback.trainingTitle,
      startsAt: fallback.startsAt,
      location: fallback.location,
      status: status,
      trainingPrice: fallback.trainingPrice,
      paymentNote: fallback.paymentNote,
      paymentProofChatId: fallback.paymentProofChatId,
      paymentProofMessageId: fallback.paymentProofMessageId,
      createdAt: fallback.createdAt,
      updatedAt: fallback.updatedAt,
    );
  }

  Future<_FreeTrainingBonusType?> _resolveFreeTrainingBonusType(int userId) async {
    final starterAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    if (starterAvailable) {
      return _FreeTrainingBonusType.starter;
    }
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    if (progress.availableRewardsCount > 0) {
      return _FreeTrainingBonusType.everyFifth;
    }
    return null;
  }

  Future<TrainingBooking?> _applyStarterBonus(TrainingBooking booking, int userId) async {
    final consumed = await _onboardingRepository.consumeStarterBonus(
      userId,
      consumedAt: _nowProvider(),
    );
    if (!consumed) {
      return null;
    }
    try {
      return _bookingRepository.updateStatus(
        booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to apply starter bonus payment status for booking ${booking.id}: $error',
          stackTrace);
      await _onboardingRepository.rollbackStarterBonusConsumption(
        userId,
        rollbackAt: _nowProvider(),
      );
      return null;
    }
  }

  Future<TrainingBooking?> _applyEveryFifthBonus(TrainingBooking booking) async {
    return _bookingRepository.updateStatus(
      booking.id,
      BookingStatus.paid,
      paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
    );
  }

  Future<void> _maybeNotifyEveryFifthRewardUnlocked({
    required int userId,
    required int chatId,
    required String? username,
  }) async {
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    final earnedRewards = progress.earnedRewardsCount;
    if (earnedRewards <= 0 || progress.availableRewardsCount <= 0) {
      return;
    }
    final lastNotified = await _onboardingRepository.getEveryFifthLastNotifiedRewards(userId);
    if (earnedRewards <= lastNotified) {
      return;
    }
    try {
      await _sender.sendMessage(
        chatId,
        _templates.everyFifthBonusUnlockedUser(
          completedTrainingsCount: progress.qualifiedTrainingsCount,
          availableRewardsCount: progress.availableRewardsCount,
        ),
      );
      await _onboardingRepository.setEveryFifthLastNotifiedRewards(
        userId,
        rewardsCount: earnedRewards,
        updatedAt: _nowProvider(),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about every-fifth reward unlock: $error', stackTrace);
    }
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.everyFifthBonusUnlockedAdmin(
          userId: userId,
          username: username,
          completedTrainingsCount: progress.qualifiedTrainingsCount,
          availableRewardsCount: progress.availableRewardsCount,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about every-fifth reward unlock: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutBookingRescheduled({
    required TrainingBooking before,
    required TrainingBooking after,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.bookingRescheduledAdminNotification(before: before, after: after),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking reschedule: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutBookingCancelled(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.bookingCancelledAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking cancellation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutFreeBookingCreated(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.freeBookingCreatedAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about free booking creation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutTrainerBookingCreated(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.trainerBookingCreatedAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about trainer booking creation: $error', stackTrace);
    }
  }

  Future<void> _maybeNotifyGroupAboutCapacity(
    TrainingInfo training, {
    required BookingStatus bookingStatus,
  }) async {
    if (!_isCapacityConfirmedBookingStatus(bookingStatus)) {
      return;
    }
    final targetChatId = _targetChatId;
    final participantsLimit = training.participantsLimit;
    if (targetChatId == null || participantsLimit == null || participantsLimit <= 0) {
      return;
    }

    final activeBookings = await _bookingRepository.listByTrainingKeys(
      <String>{training.sessionKey},
      limit: participantsLimit,
    );
    final confirmedBookings = activeBookings
        .where((booking) => _isCapacityConfirmedBookingStatus(booking.status))
        .toList();
    final participantsCount = _countParticipantsForTraining(
      bookings: confirmedBookings,
      training: training,
    );
    final freeSpots = participantsLimit - participantsCount;
    if (freeSpots <= 0) {
      if (_fullCapacityNotifiedTrainingKeys.contains(training.sessionKey)) {
        return;
      }
      try {
        final messageId = await _sender.sendMessage(
          targetChatId,
          _templates.groupTrainingNoSpotsLeft(
            training: training,
            participantsLimit: participantsLimit,
          ),
          parseMode: 'HTML',
        );
        _lastCapacityGroupMessageId = messageId;
        _lastCapacityGroupMessageType = _CapacityGroupNotificationType.noSpots;
        _fullCapacityNotifiedTrainingKeys.add(training.sessionKey);
        _lowCapacityNotifiedTrainingKeys.add(training.sessionKey);
      } on Object catch (error, stackTrace) {
        l.w('Failed to notify group about full training capacity: $error', stackTrace);
      }
      return;
    }

    final freeShare = freeSpots / participantsLimit;
    if (freeShare >= 0.3 || _lowCapacityNotifiedTrainingKeys.contains(training.sessionKey)) {
      return;
    }

    try {
      final previousLowCapacityMessageId =
          _lastCapacityGroupMessageType == _CapacityGroupNotificationType.lowSpots
              ? _lastCapacityGroupMessageId
              : null;
      if (previousLowCapacityMessageId != null) {
        try {
          await _sender.deleteMessage(
            targetChatId,
            messageId: previousLowCapacityMessageId,
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed to delete previous low-capacity group notification: $error',
            stackTrace,
          );
        }
      }
      final messageId = await _sender.sendMessage(
        targetChatId,
        _templates.groupTrainingLowSpots(
          training: training,
          freeSpots: freeSpots,
          participantsLimit: participantsLimit,
        ),
        parseMode: 'HTML',
      );
      _lastCapacityGroupMessageId = messageId;
      _lastCapacityGroupMessageType = _CapacityGroupNotificationType.lowSpots;
      _lowCapacityNotifiedTrainingKeys.add(training.sessionKey);
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify group about low training capacity: $error', stackTrace);
    }
  }

  Future<void> _notifyUserAboutAdminBookingDeleted(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return;
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingDeletedForUser(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking deletion: $error', stackTrace);
    }
  }

  bool _shouldShowOutdoorPaymentTypeChoice(TrainingBooking booking) {
    return _bookingPolicyService.shouldShowOutdoorPaymentTypeChoice(booking);
  }

  String? _composePaymentNote({
    required String? caption,
    required PaymentChoice? choice,
  }) {
    final normalizedCaption = caption?.trim();
    final marker = switch (choice) {
      PaymentChoice.full => _paymentChoiceFullMarker,
      PaymentChoice.partial => _paymentChoicePartialMarker,
      null => null,
    };
    if (marker == null) {
      return normalizedCaption;
    }
    if (normalizedCaption == null || normalizedCaption.isEmpty) {
      return marker;
    }
    return '$marker\n$normalizedCaption';
  }

  bool _hasPartialPaymentChoice(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return false;
    }
    return paymentNote.startsWith(_paymentChoicePartialMarker);
  }

  int _countParticipantsForTraining({
    required List<TrainingBooking> bookings,
    required TrainingInfo training,
  }) {
    if (training.includeTrainersInParticipants) {
      return bookings.length;
    }
    return bookings
        .where((booking) => !_isWhitelistedTrainerBooking(
              userId: booking.userId,
              username: booking.userUsername,
            ))
        .length;
  }

  bool _isWhitelistedTrainerBooking({
    required int userId,
    required String? username,
  }) {
    return isTrainerBookingWhitelisted(userId: userId, username: username);
  }

  bool _isWhitelistedTrainerBookingByBooking(TrainingBooking booking) {
    return _isWhitelistedTrainerBooking(userId: booking.userId, username: booking.userUsername);
  }

  bool _isCapacityConfirmedBookingStatus(BookingStatus status) {
    return status == BookingStatus.paid ||
        status == BookingStatus.partialPaid ||
        status == BookingStatus.freeTraining;
  }

  bool _shouldNotifyAdminAboutBookingCancellation(TrainingBooking booking) {
    return _isCapacityConfirmedBookingStatus(booking.status);
  }

  TrainingInfo _trainingInfoFromBooking(TrainingBooking booking) {
    return TrainingInfo(
      title: booking.trainingTitle,
      startsAt: booking.startsAt,
      location: booking.location,
      category: _catalogService.categoryForBooking(booking),
    );
  }

  Future<void> _openPaymentFlowForBooking({
    required int chatId,
    required int userId,
    required TrainingBooking booking,
  }) async {
    final starterBonusOffered =
        _catalogService.categoryForBooking(booking) == _ActivityCategory.trainings &&
            await _hasAnyFreeTrainingBonusAvailable(userId);
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.paymentConfirmation,
      availableTrainings: const <TrainingInfo>[],
      activeBooking: booking,
      starterBonusOffered: starterBonusOffered,
      paymentChoice: null,
    );
    await _sender.sendMessage(
      chatId,
      _templates.paymentDetailsSent(booking),
      replyMarkup: _templates.paymentConfirmationKeyboard(
        showStarterBonus: starterBonusOffered,
        showCancelBooking: _canCancelBookingByPolicy(booking),
        showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(booking),
      ),
    );
  }

  Future<bool> _openPendingPaymentFlow({
    required int chatId,
    required int userId,
  }) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 20);
    final pending = bookings
        .where(
          (item) =>
              item.status == BookingStatus.pendingPayment ||
              item.status == BookingStatus.partialPaid,
        )
        .toList();
    if (pending.isEmpty) {
      return false;
    }
    pending.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: pending.first);
    return true;
  }

  Future<TrainingBooking?> _resolveLatestPendingPaymentBooking(int userId) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 20);
    final pending = bookings.where((item) => item.status == BookingStatus.pendingPayment).toList();
    if (pending.isEmpty) {
      return null;
    }
    pending.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return pending.first;
  }

  bool _canCancelBookingByPolicy(TrainingBooking booking) {
    return _bookingPolicyService.canCancel(booking, now: _nowProvider());
  }

  String _cancellationTooLateText(
    TrainingBooking booking, {
    required _ActivityCategory category,
  }) {
    if (category == _ActivityCategory.yoga) {
      return _templates.yogaCancellationTooLate(booking);
    }
    return _templates.outdoorCancellationTooLate(booking);
  }

  _EconomicSummaryRange? _parseEconomicSummaryRangeCommand(String text) {
    if (!text.startsWith('/economic_summary')) {
      return null;
    }
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return switch (parts[1].toLowerCase()) {
      'current_week' || 'current-week' || 'cw' => _EconomicSummaryRange.currentWeek,
      'previous_week' ||
      'prev_week' ||
      'previous-week' ||
      'prev-week' ||
      'pw' =>
        _EconomicSummaryRange.previousWeek,
      'current_month' || 'current-month' || 'cm' => _EconomicSummaryRange.currentMonth,
      'previous_month' ||
      'prev_month' ||
      'previous-month' ||
      'prev-month' ||
      'pm' =>
        _EconomicSummaryRange.previousMonth,
      _ => null,
    };
  }

  _EconomicSummaryRange? _parseEconomicSummaryRangeText(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('текущ') && normalized.contains('недел')) {
      return _EconomicSummaryRange.currentWeek;
    }
    if (normalized.contains('прошл') && normalized.contains('недел')) {
      return _EconomicSummaryRange.previousWeek;
    }
    if (normalized.contains('текущ') && normalized.contains('месяц')) {
      return _EconomicSummaryRange.currentMonth;
    }
    if (normalized.contains('прошл') && normalized.contains('месяц')) {
      return _EconomicSummaryRange.previousMonth;
    }
    return null;
  }
}

typedef _PrivateFlowState = PrivateFlowState;
typedef _PrivateFlowStep = PrivateFlowStep;
typedef _ActivityCategory = ActivityCategory;

enum _FreeTrainingBonusType { starter, everyFifth }

enum _CapacityGroupNotificationType { lowSpots, noSpots }

enum _EconomicSummaryRange {
  currentWeek('за текущую неделю'),
  previousWeek('за прошлую неделю'),
  currentMonth('за текущий месяц'),
  previousMonth('за прошлый месяц');

  const _EconomicSummaryRange(this.label);

  final String label;
}
