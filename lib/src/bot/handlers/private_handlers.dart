import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/application/payment_review_service.dart';
import 'package:dvor_chatbot/src/application/schedule_query_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/admin_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/booking_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/payment_handler.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_context.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_update_router.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/schedule_handler.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class PrivateHandlers {
  PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    OnboardingRepository onboardingRepository = const NoopOnboardingRepository(),
    TrainerDirectoryRepository trainerDirectoryRepository = const NoopTrainerDirectoryRepository(),
    required MessageTemplates templates,
    required Set<int> adminUserIds,
    int? adminChatId,
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _trainerDirectoryRepository = trainerDirectoryRepository,
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final TrainerDirectoryRepository _trainerDirectoryRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final DateTime Function() _nowProvider;
  final Map<int, PrivateFlowState> _flowByUserId = <int, PrivateFlowState>{};
  late final ActivityCatalogService _catalogService =
      ActivityCatalogService(scheduleRepository: _scheduleRepository);
  late final ScheduleQueryService _scheduleQueryService =
      ScheduleQueryService(catalogService: _catalogService, templates: _templates);
  late final PaymentReviewService _paymentReviewService =
      PaymentReviewService(bookingRepository: _bookingRepository, catalogService: _catalogService);
  late final NoblesListService _noblesListService =
      NoblesListService(bookingRepository: _bookingRepository, catalogService: _catalogService);
  final PrivateUpdateRouter _updateRouter = const PrivateUpdateRouter();
  final ScheduleHandler _scheduleHandler = const ScheduleHandler();
  final BookingHandler _bookingHandler = const BookingHandler();
  final PaymentHandler _paymentHandler = const PaymentHandler();
  final AdminHandler _adminHandler = const AdminHandler();

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
    final text = context.text;
    final rawUserId = context.from?['id'];
    final userId = rawUserId is int ? rawUserId : null;
    final isAdmin = userId != null && _adminUserIds.contains(userId);
    final canRunAdminAction = _adminHandler.canRunAdminAction(isAdmin: isAdmin);
    final flowState = userId == null ? null : _flowByUserId[userId];
    final paymentProof = extractPaymentProof(context.message);
    if (_isIgnorableServiceMessage(context.message)) {
      return true;
    }

    if (text != null && text.startsWith('/start')) {
      var starterBonusAvailable = false;
      if (userId != null) {
        _flowByUserId.remove(userId);
        await _handleStartCleanup(userId);
        starterBonusAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
        await _maybeNotifyEveryFifthRewardUnlocked(
          userId: userId,
          chatId: chatId,
          username: context.from?['username']?.toString(),
        );
      }
      final welcomeMessageId = await _sender.sendMessage(
        chatId,
        _templates.privateWelcome(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      await _tryPinWelcomeMessage(chatId: chatId, messageId: welcomeMessageId);
      if (starterBonusAvailable) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusOnboardingOffer(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
      }
      return true;
    }

    if (text != null &&
        (text.startsWith('/trainings') || text == MessageTemplates.buttonTrainings)) {
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingScheduleCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseScheduleCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text.startsWith('/coaches') || text == MessageTemplates.buttonCoachingStaff)) {
      if (userId != null) {
        _flowByUserId.remove(userId);
      }
      final refreshOk = await _trainerDirectoryRepository.refresh();
      if (!refreshOk) {
        l.w('Trainer directory refresh failed. Using cached trainers list.');
      }
      final trainers = _trainerDirectoryRepository.list(limit: 30);
      await _sender.sendMessage(
        chatId,
        _templates.coachingStaff(trainers),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonHelp) {
      if (userId != null) {
        _flowByUserId.remove(userId);
      }
      await _sender.sendMessage(
        chatId,
        _templates.privateHelp(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonMainMenu) {
      if (userId == null) {
        return false;
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        'Главное меню 👇',
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonBack) {
      if (userId == null) {
        return false;
      }
      switch (flowState?.step) {
        case _PrivateFlowStep.selectingScheduleCategory:
        case _PrivateFlowStep.selectingBookingCategory:
        case _PrivateFlowStep.selectingParticipantsCategory:
        case _PrivateFlowStep.selectingPaymentsQueueCategory:
        case _PrivateFlowStep.selectingBookingToManage:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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
            _flowByUserId[userId] = flowState!.copyWith(
              step: _PrivateFlowStep.viewingScheduleCategory,
              availableTrainings: const <TrainingInfo>[],
            );
            await _sender.sendMessage(
              chatId,
              _scheduleTextByCategory(selectedCategory),
              replyMarkup: _templates.scheduleCategoryActionsKeyboard(),
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
        case _PrivateFlowStep.selectingBookingAction:
          final bookings = flowState!.availableBookings;
          _flowByUserId[userId] =
              flowState.copyWith(step: _PrivateFlowStep.selectingBookingToManage);
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingToManage(bookings),
            replyMarkup: _templates.bookingManagementSelectionKeyboard(bookings),
          );
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
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingAction:
          final bookings = flowState!.availableBookings;
          _flowByUserId[userId] = flowState.copyWith(
            step: _PrivateFlowStep.selectingAdminBookingFromList,
            selectedBooking: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseAdminBookingFromList(bookings),
            replyMarkup: _templates.bookingManagementSelectionKeyboard(bookings),
          );
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
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.viewingScheduleCategory,
        availableTrainings: const <TrainingInfo>[],
        selectedCategory: category,
      );
      await _sender.sendMessage(
        chatId,
        _scheduleTextByCategory(category),
        replyMarkup: _templates.scheduleCategoryActionsKeyboard(),
      );
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
      final result = await _bookingRepository.createPendingBooking(
        userId: userId,
        userUsername: context.from?['username']?.toString(),
        training: flowState.availableTrainings[index - 1],
      );
      final selectedTraining = flowState.availableTrainings[index - 1];
      if (_isFreeActivity(selectedTraining)) {
        final paidBooking =
            await _bookingRepository.updateStatus(result.booking.id, BookingStatus.paid);
        final bookingForResponse =
            _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          result.created
              ? _templates.bookingCreatedWithoutPayment(bookingForResponse)
              : _templates.bookingAlreadyExists(bookingForResponse),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final starterBonusOffered = selectedTraining.category == _ActivityCategory.trainings &&
          await _hasAnyFreeTrainingBonusAvailable(userId);
      _flowByUserId[userId] = flowState.copyWith(
        step: _PrivateFlowStep.paymentConfirmation,
        activeBooking: result.booking,
        starterBonusOffered: starterBonusOffered,
      );
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreated(result.booking)
            : _templates.bookingAlreadyExists(result.booking),
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: starterBonusOffered,
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonMyBookings || text.startsWith('/my_bookings'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: context.from?['username']?.toString(),
      );
      final bookings = await _bookingRepository.listUserBookings(userId);
      final activeBookings = bookings
          .where(
            (booking) =>
                booking.status != BookingStatus.cancelled &&
                !booking.startsAt.isBefore(_nowProvider()),
          )
          .toList(growable: false);
      await _sender.sendMessage(
        chatId,
        _templates.myBookings(bookings, now: _nowProvider()),
        replyMarkup: activeBookings.isEmpty
            ? _templates.privateMenuKeyboard(isAdmin: isAdmin)
            : _templates.bookingManagementSelectionKeyboard(activeBookings),
      );
      if (activeBookings.isNotEmpty) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingBookingToManage,
          availableTrainings: const <TrainingInfo>[],
          availableBookings: activeBookings,
        );
        await _sender.sendMessage(
          chatId,
          _templates.chooseBookingToManage(activeBookings),
          replyMarkup: _templates.bookingManagementSelectionKeyboard(activeBookings),
        );
      }
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingToManage &&
        text != null &&
        !text.startsWith('/')) {
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
        await _sender.sendMessage(
          chatId,
          _templates.chooseBookingToManage(currentFlow.availableBookings),
          replyMarkup: _templates.bookingManagementSelectionKeyboard(currentFlow.availableBookings),
        );
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
      if (selectedBooking == null ||
          _catalogService.categoryForBooking(selectedBooking) != _ActivityCategory.trainings) {
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final trainings = _bookableItemsByCategory(_ActivityCategory.trainings);
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
      if (selectedBooking == null ||
          !_isOutdoorCategory(_catalogService.categoryForBooking(selectedBooking))) {
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final canCancel =
          selectedBooking.startsAt.difference(_nowProvider()) >= const Duration(days: 7);
      if (!canCancel) {
        await _sender.sendMessage(
          chatId,
          _templates.outdoorCancellationTooLate(selectedBooking),
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
        await _notifyAdminAboutBookingCancelled(cancelResult.booking!);
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
        paymentProof != null) {
      final currentFlow = flowState!;
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        bookingId: currentFlow.activeBooking?.id,
        note: paymentProof.caption,
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

    if (text != null &&
        (text == MessageTemplates.buttonSubmitPayment || text.startsWith('/paid'))) {
      if (userId == null) {
        return false;
      }
      if (flowState?.step != _PrivateFlowStep.paymentConfirmation) {
        await _sender.sendMessage(
          chatId,
          _paymentHandler.chooseBookingFirstText(MessageTemplates.buttonBookTraining),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.paymentProofRequired(),
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: flowState?.starterBonusOffered ?? false,
        ),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        !text.startsWith('/')) {
      await _sender.sendMessage(
        chatId,
        _templates.paymentProofRequired(),
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: flowState!.starterBonusOffered,
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonRefreshSchedule || text.startsWith('/refresh_schedule'))) {
      if (!canRunAdminAction) {
        await _sender.sendMessage(
          chatId,
          _templates.scheduleRefreshForbidden(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final refreshOk = await _scheduleRepository.refresh(force: true);
      await _sender.sendMessage(
        chatId,
        refreshOk ? _templates.scheduleRefreshDone() : _templates.scheduleRefreshFailed(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      await _sender.sendMessage(chatId, _templates.scheduleDocumentLink());
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonPaymentsQueue || text.startsWith('/payments_queue'))) {
      if (!canRunAdminAction) {
        await _sender.sendMessage(
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
      await _sender.sendMessage(
        chatId,
        _templates.choosePaymentsQueueCategory(),
        replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
          trainings: counters.trainings,
          hikes: counters.hikes,
          trails: counters.trails,
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonParticipantsList ||
            text.startsWith('/participants_list'))) {
      if (!canRunAdminAction) {
        await _sender.sendMessage(
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
        step: _PrivateFlowStep.selectingParticipantsCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseParticipantsCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonNoblesList || text.startsWith('/nobles_list'))) {
      if (!canRunAdminAction) {
        await _sender.sendMessage(
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
        await _sender.sendMessage(
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
      await _sender.sendMessage(
        chatId,
        _templates.chooseBookingManagementAction(),
        replyMarkup: _templates.adminBookingManagementKeyboard(),
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
      final bookings = await _bookingRepository.adminListBookings(
        category: category,
        archived: archived,
      );
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingFromList,
        selectedCategory: category,
        availableBookings: bookings,
        selectedBooking: null,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseAdminBookingFromList(bookings),
        replyMarkup: bookings.isEmpty
            ? _templates.adminBookingManagementKeyboard()
            : _templates.bookingManagementSelectionKeyboard(bookings),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingFromList &&
        text != null &&
        !text.startsWith('/')) {
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
        await _sender.sendMessage(
          chatId,
          _templates.chooseAdminBookingFromList(bookings),
          replyMarkup: bookings.isEmpty
              ? _templates.adminBookingManagementKeyboard()
              : _templates.bookingManagementSelectionKeyboard(bookings),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingAction,
        selectedBooking: selectedBooking,
      );
      await _sender.sendMessage(
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
      await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingActions(selectedBooking),
          replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
        );
        return true;
      }

      if (text == MessageTemplates.buttonConfirmDeleteBooking) {
        final archived = await _bookingRepository.adminArchiveBooking(selectedBooking.id);
        if (archived == null) {
          await _sender.sendMessage(
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (restored == null) {
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.chooseAdminBookingPaymentStatus(selectedBooking),
          replyMarkup: _templates.bookingPaymentStatusKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingUsername) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.enteringAdminBookingUsername);
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingAskUsername(selectedBooking),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingAskUsername(selectedBooking),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final items = _bookableItemsByCategory(category);
      if (items.isEmpty) {
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
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
      await _sender.sendMessage(
        chatId,
        _templates.createBookingAskUsername(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminCreateUsername &&
        text != null &&
        !text.startsWith('/')) {
      final normalizedUsername = _normalizeUsernameInput(text);
      if (normalizedUsername == null) {
        await _sender.sendMessage(
          chatId,
          _templates.createBookingAskUsername(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminCreateStatus,
        adminCreateUsername: normalizedUsername,
      );
      await _sender.sendMessage(
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
        await _sender.sendMessage(
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
      await _sender.sendMessage(
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
        await _sender.sendMessage(
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
        await _sender.sendMessage(
          chatId,
          _templates.adminBookingCreated(created),
          replyMarkup: _templates.adminBookingAfterActionKeyboard(),
        );
        return true;
      }
    }

    if (text != null &&
        (text.startsWith('/approve_payment') || text.startsWith('/reject_payment'))) {
      if (!isAdmin) {
        await _sender.sendMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        await _sender.sendMessage(
          chatId,
          _templates.paymentActionUsage(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final status =
          text.startsWith('/approve_payment') ? BookingStatus.paid : BookingStatus.paymentRejected;
      final reviewResult = await _bookingRepository.reviewSubmittedPayment(
        bookingId: bookingId,
        status: status,
      );
      final booking = reviewResult.booking;
      if (reviewResult.outcome == PaymentReviewOutcome.success && booking != null) {
        await _notifyAboutPaymentReview(
          booking,
          moderatorUserId: userId,
          moderatorUsername: context.from?['username']?.toString(),
        );
      }
      await _sender.sendMessage(
        chatId,
        switch (reviewResult.outcome) {
          PaymentReviewOutcome.success => _templates.bookingStatusUpdated(booking!),
          PaymentReviewOutcome.notFound => _templates.bookingNotFound(bookingId),
          PaymentReviewOutcome.invalidStatus => _templates.paymentAlreadyReviewed(bookingId),
        },
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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

  List<TrainingInfo> _bookableItemsByCategory(_ActivityCategory category) {
    return _catalogService.bookableItems(category);
  }

  Future<void> _sendParticipantsByCategory({
    required int chatId,
    required _ActivityCategory category,
    required bool isAdmin,
  }) async {
    final trainings = _participantItemsByCategory(category);
    final activeBookings = await _bookingRepository.adminListBookings(
      category: category,
      archived: false,
      limit: 500,
    );
    final trainingsByKey = <String, TrainingInfo>{
      for (final training in trainings) training.sessionKey: training,
    };
    for (final booking in activeBookings) {
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
    final keys = trainingsByKey.keys.toSet();
    final bookings = keys.isEmpty
        ? const <TrainingBooking>[]
        : await _bookingRepository.listByTrainingKeys(keys, limit: 1000);
    final byTraining = <String, List<TrainingBooking>>{};
    for (final booking in bookings) {
      byTraining.putIfAbsent(booking.trainingKey, () => <TrainingBooking>[]).add(booking);
    }

    final copy = _scheduleHandler.participantsCopy(category);

    await _sender.sendMessage(
      chatId,
      _templates.trainingParticipants(
        trainings: mergedTrainings,
        bookingsByTrainingKey: byTraining,
        title: copy.title,
        emptyText: copy.emptyText,
      ),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
    );
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

    await _sender.sendMessage(chatId, _templates.paymentsQueueIntro(filtered.length));
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
        }
      }
      await _sender.sendMessage(
        chatId,
        _templates.paymentsQueueItem(booking),
        replyMarkup: _templates.paymentDecisionInlineKeyboard(booking.id),
      );
    }
  }

  Future<void> _sendNoblesList({
    required int chatId,
    required bool isAdmin,
  }) async {
    final result = await _noblesListService.buildStats();
    await _sender.sendMessage(
      chatId,
      _templates.noblesList(result.users, totalTrainings: result.totalTrainings),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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

  BookingStatus? _parsePaymentStatusSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('ожидает')) {
      return BookingStatus.pendingPayment;
    }
    if (normalized.contains('проверке') || normalized.contains('проверк')) {
      return BookingStatus.paymentSubmitted;
    }
    if (normalized.contains('оплачен') || normalized.contains('оплачено')) {
      return BookingStatus.paid;
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

  Future<void> _openAdminBookingListSegment({
    required int chatId,
    required int userId,
  }) async {
    final counters = await _bookingRepository.adminCountBySegment();
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.selectingAdminBookingListSegment,
      availableTrainings: <TrainingInfo>[],
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseBookingListSegment(),
      replyMarkup: _templates.bookingSegmentKeyboard(
        activeCount: counters.active,
        archivedCount: counters.archived,
      ),
    );
  }

  bool _isOutdoorCategory(_ActivityCategory category) {
    return category == _ActivityCategory.hikes || category == _ActivityCategory.trails;
  }

  Map<String, Object?> _bookingActionsKeyboard(TrainingBooking booking) {
    final category = _catalogService.categoryForBooking(booking);
    return _templates.bookingActionsKeyboard(
      canReschedule: category == _ActivityCategory.trainings,
      canCancel: _isOutdoorCategory(category),
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

  Future<void> _notifyAdminAboutPaymentSubmitted(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      final counters = await _paymentReviewService.queueCounters();
      await _sender.sendMessage(
        adminChatId,
        _templates.paymentSubmittedAdminNotification(booking),
        replyMarkup: _templates.openPaymentsQueueInlineKeyboard(total: counters.total),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment submission: $error', stackTrace);
    }
  }

  Future<void> _notifyAboutPaymentReview(
    TrainingBooking booking, {
    required int? moderatorUserId,
    String? moderatorUsername,
  }) async {
    try {
      await _sender.sendMessage(
        booking.userId,
        booking.status == BookingStatus.paid
            ? _templates.paymentApprovedForUser(booking)
            : _templates.paymentRejectedForUser(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about payment review: $error', stackTrace);
    }

    final adminChatId = _adminChatId;
    if (adminChatId == null || moderatorUserId == null) {
      return;
    }
    try {
      await _sender.sendMessage(
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
      await _sender.sendMessage(
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
      await _sender.sendMessage(
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
    return _bookingRepository.updateStatus(
      booking.id,
      BookingStatus.paid,
      paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
    );
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
    await _onboardingRepository.setEveryFifthLastNotifiedRewards(
      userId,
      rewardsCount: earnedRewards,
      updatedAt: _nowProvider(),
    );
    try {
      await _sender.sendMessage(
        chatId,
        _templates.everyFifthBonusUnlockedUser(
          completedTrainingsCount: progress.qualifiedTrainingsCount,
          availableRewardsCount: progress.availableRewardsCount,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about every-fifth reward unlock: $error', stackTrace);
    }
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sender.sendMessage(
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
      await _sender.sendMessage(
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
      await _sender.sendMessage(
        adminChatId,
        _templates.bookingCancelledAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking cancellation: $error', stackTrace);
    }
  }
}

typedef _PrivateFlowState = PrivateFlowState;
typedef _PrivateFlowStep = PrivateFlowStep;
typedef _ActivityCategory = ActivityCategory;

enum _FreeTrainingBonusType { starter, everyFifth }
