import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';

final class FakeScheduleRepository implements TrainingScheduleRepository {
  FakeScheduleRepository(
    this._items, {
    this.outdoorItems = const <OutdoorActivityInfo>[],
    this.refreshResult = true,
  });

  final List<TrainingInfo> _items;
  final List<OutdoorActivityInfo> outdoorItems;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) => _items.take(limit).toList();

  @override
  List<OutdoorActivityInfo> upcomingOutdoorActivities({DateTime? now, int limit = 8}) =>
      outdoorItems.take(limit).toList();

  @override
  Future<bool> refresh({bool force = false}) async {
    refreshCalls += 1;
    return refreshResult;
  }
}

final class FakeBookingRepository implements BookingRepository {
  int createCalls = 0;
  int submitCalls = 0;
  int reviewCalls = 0;
  int cancelCalls = 0;
  int rescheduleCalls = 0;
  int? lastSubmittedBookingId;
  List<TrainingBooking> queue = const <TrainingBooking>[];
  List<TrainingBooking> bookingsByTrainingKey = const <TrainingBooking>[];
  List<TrainingBooking> userBookings = const <TrainingBooking>[];
  TrainingBooking? submitResult;
  TrainingInfo? lastCreatedTraining;
  String? lastCreatedUsername;
  Exception? createException;
  int? lastCancelledBookingId;
  int? lastRescheduledBookingId;
  TrainingInfo? lastRescheduleTraining;
  BookingActionResult cancelResult = const BookingActionResult(
    outcome: BookingActionOutcome.success,
  );
  BookingRescheduleResult rescheduleResult = const BookingRescheduleResult(
    outcome: BookingRescheduleOutcome.success,
  );
  List<TrainingBooking> pendingForReminder = const <TrainingBooking>[];
  int remindersMarked = 0;
  ({int active, int archived}) adminSegmentCounts = (active: 0, archived: 0);
  List<TrainingBooking> adminBookings = const <TrainingBooking>[];
  ActivityCategory? lastAdminListCategory;
  bool? lastAdminListArchived;
  int adminArchiveCalls = 0;
  int? lastAdminArchivedBookingId;
  EveryFifthRewardProgress everyFifthProgress = const EveryFifthRewardProgress(
    qualifiedTrainingsCount: 0,
    usedRewardsCount: 0,
  );
  PaymentReviewResult? paymentReviewResult;
  bool throwAdminUpdateConflict = false;
  final Set<String> sentEconomicReports = <String>{};

  @override
  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    String? userUsername,
    required TrainingInfo training,
  }) async {
    createCalls += 1;
    lastCreatedTraining = training;
    lastCreatedUsername = userUsername;
    final configuredException = createException;
    if (configuredException != null) {
      throw configuredException;
    }
    return BookingCreateResult(
      booking: fakeBooking(
        id: 99,
        userId: userId,
        userUsername: userUsername,
        title: training.title,
        startsAt: training.startsAt,
        location: training.location,
        trainingPrice: training.price,
      ),
      created: true,
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<List<TrainingBooking>> listByStatus(
    BookingStatus status, {
    int limit = 20,
  }) async {
    return queue.where((item) => item.status == status).take(limit).toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listByTrainingKeys(
    Set<String> trainingKeys, {
    int limit = 200,
    bool includeCancelled = false,
  }) async {
    return bookingsByTrainingKey
        .where(
          (booking) =>
              trainingKeys.contains(booking.trainingKey) &&
              (includeCancelled || booking.status != BookingStatus.cancelled) &&
              booking.status != BookingStatus.paymentRejected,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10}) async {
    if (userBookings.isEmpty) {
      return <TrainingBooking>[
        fakeBooking(
          id: 1,
          userId: userId,
          title: 'Test booking',
          startsAt: DateTime(2026, 7, 10, 18),
          location: 'Gym',
        ),
      ];
    }
    final now = DateTime.now();
    final filtered = userBookings
        .where((booking) => booking.userId == userId)
        .toList(growable: false)
      ..sort((left, right) {
        final leftRank = left.status != BookingStatus.cancelled && !left.startsAt.isBefore(now)
            ? 0
            : left.status != BookingStatus.cancelled
                ? 1
                : 2;
        final rightRank = right.status != BookingStatus.cancelled && !right.startsAt.isBefore(now)
            ? 0
            : right.status != BookingStatus.cancelled
                ? 1
                : 2;
        if (leftRank != rightRank) {
          return leftRank.compareTo(rightRank);
        }
        if (leftRank == 0) {
          return left.startsAt.compareTo(right.startsAt);
        }
        if (leftRank == 1) {
          return right.startsAt.compareTo(left.startsAt);
        }
        return right.updatedAt.compareTo(left.updatedAt);
      });
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<BookingActionResult> cancelBooking({
    required int userId,
    required int bookingId,
  }) async {
    cancelCalls += 1;
    lastCancelledBookingId = bookingId;
    return cancelResult;
  }

  @override
  Future<BookingRescheduleResult> rescheduleBooking({
    required int userId,
    required int bookingId,
    required TrainingInfo training,
  }) async {
    rescheduleCalls += 1;
    lastRescheduledBookingId = bookingId;
    lastRescheduleTraining = training;
    return rescheduleResult;
  }

  @override
  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    int? bookingId,
    String? note,
    int? paymentProofChatId,
    int? paymentProofMessageId,
  }) async {
    submitCalls += 1;
    lastSubmittedBookingId = bookingId;
    return submitResult;
  }

  @override
  Future<TrainingBooking?> updateStatus(
    int bookingId,
    BookingStatus status, {
    String? paymentNote,
  }) async {
    final training = lastCreatedTraining;
    return fakeBooking(
      id: bookingId,
      status: status,
      paymentNote: paymentNote,
      title: training?.title ?? 'Training',
      startsAt: training?.startsAt,
      location: training?.location ?? 'Hall',
      trainingPrice: training?.price,
    );
  }

  @override
  Future<PaymentReviewResult> reviewSubmittedPayment({
    required int bookingId,
    required BookingStatus status,
  }) async {
    reviewCalls += 1;
    final configured = paymentReviewResult;
    if (configured != null) {
      return configured;
    }
    final booking = fakeBooking(id: bookingId, status: status);
    return PaymentReviewResult(
      outcome: PaymentReviewOutcome.success,
      booking: booking,
    );
  }

  @override
  Future<List<TrainingBooking>> listPendingPaymentForReminder({
    required DateTime createdBefore,
    required DateTime remindedBefore,
    int limit = 20,
  }) async {
    return pendingForReminder.take(limit).toList(growable: false);
  }

  @override
  Future<void> markReminderSent(int bookingId) async {
    remindersMarked += 1;
  }

  @override
  Future<List<TrainingBooking>> listPaidBookingsInRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
    int limit = 5000,
  }) async {
    return queue
        .where(
          (booking) =>
              (booking.status == BookingStatus.paid ||
                  booking.status == BookingStatus.freeTraining) &&
              !booking.updatedAt.isBefore(fromInclusive) &&
              booking.updatedAt.isBefore(toExclusive),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<bool> tryMarkEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime sentAt,
  }) async {
    final key =
        '$reportType|${periodStart.toUtc().toIso8601String()}|${periodEnd.toUtc().toIso8601String()}';
    return sentEconomicReports.add(key);
  }

  @override
  Future<void> rollbackEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final key =
        '$reportType|${periodStart.toUtc().toIso8601String()}|${periodEnd.toUtc().toIso8601String()}';
    sentEconomicReports.remove(key);
  }

  @override
  Future<({int active, int archived})> adminCountBySegment() async {
    return adminSegmentCounts;
  }

  @override
  Future<List<TrainingBooking>> adminListBookings({
    required ActivityCategory category,
    required bool archived,
    int limit = 30,
  }) async {
    lastAdminListCategory = category;
    lastAdminListArchived = archived;
    return adminBookings.take(limit).toList(growable: false);
  }

  @override
  Future<TrainingBooking> adminCreateBooking({
    int userId = 0,
    required String userUsername,
    required TrainingInfo training,
    required BookingStatus status,
  }) async {
    final created = fakeBooking(
      id: 777,
      userId: userId,
      userUsername: userUsername,
      trainingKey: training.sessionKey,
      title: training.title,
      startsAt: training.startsAt,
      location: training.location,
      status: status,
    );
    adminBookings = <TrainingBooking>[...adminBookings, created];
    return created;
  }

  @override
  Future<TrainingBooking?> adminUpdateBooking({
    required int bookingId,
    String? userUsername,
    TrainingInfo? training,
    BookingStatus? status,
  }) async {
    if (throwAdminUpdateConflict) {
      throw const BookingConflictException('conflict');
    }
    final index = adminBookings.indexWhere((item) => item.id == bookingId);
    if (index < 0) {
      return null;
    }
    final current = adminBookings[index];
    final updated = fakeBooking(
      id: current.id,
      userId: current.userId,
      userUsername: userUsername ?? current.userUsername,
      trainingKey: training?.sessionKey ?? current.trainingKey,
      title: training?.title ?? current.trainingTitle,
      startsAt: training?.startsAt ?? current.startsAt,
      location: training?.location ?? current.location,
      status: status ?? current.status,
      paymentNote: current.paymentNote,
    );
    final items = adminBookings.toList(growable: true);
    items[index] = updated;
    adminBookings = items;
    return updated;
  }

  @override
  Future<TrainingBooking?> adminArchiveBooking(int bookingId) async {
    adminArchiveCalls += 1;
    lastAdminArchivedBookingId = bookingId;
    return adminUpdateBooking(bookingId: bookingId, status: BookingStatus.cancelled);
  }

  @override
  Future<EveryFifthRewardProgress> getEveryFifthRewardProgress(
    int userId, {
    required DateTime now,
  }) async {
    return everyFifthProgress;
  }
}

final class FakeTrainerDirectoryRepository implements TrainerDirectoryRepository {
  FakeTrainerDirectoryRepository(
    this.items, {
    this.refreshResult = true,
  });

  final List<TrainerInfo> items;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<TrainerInfo> list({int limit = 20}) => items.take(limit).toList(growable: false);

  @override
  Future<bool> refresh({bool force = false}) async {
    refreshCalls += 1;
    return refreshResult;
  }
}

TrainingBooking fakeBooking({
  int id = 10,
  int userId = 1,
  String? userUsername,
  int? paymentProofChatId,
  int? paymentProofMessageId,
  String? trainingKey,
  String title = 'Training',
  DateTime? startsAt,
  String location = 'Hall',
  BookingStatus status = BookingStatus.pendingPayment,
  int? trainingPrice,
  String? paymentNote,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 1, 1, 10);
  return TrainingBooking(
    id: id,
    userId: userId,
    userUsername: userUsername,
    trainingKey: trainingKey ?? 'key-$id',
    trainingTitle: title,
    startsAt: startsAt ?? DateTime(2026, 8, 1, 18),
    location: location,
    status: status,
    trainingPrice: trainingPrice,
    paymentNote: paymentNote,
    paymentProofChatId: paymentProofChatId,
    paymentProofMessageId: paymentProofMessageId,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

final class FakeSender implements MessageSender {
  final List<SentMessage> messages = <SentMessage>[];
  final List<CopiedMessage> copiedMessages = <CopiedMessage>[];
  final List<DeletedMessage> deletedMessages = <DeletedMessage>[];
  final List<PinnedMessage> pinnedMessages = <PinnedMessage>[];
  final List<AnsweredCallback> answeredCallbacks = <AnsweredCallback>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) async {
    messages.add(
      SentMessage(
        chatId: chatId,
        text: text,
        disableNotification: disableNotification,
        disableWebPagePreview: disableWebPagePreview,
        replyMarkup: replyMarkup,
        parseMode: parseMode,
      ),
    );
    return messages.length;
  }

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) async {
    copiedMessages.add(
      CopiedMessage(
        toChatId: chatId,
        fromChatId: fromChatId,
        messageId: messageId,
        disableNotification: disableNotification,
      ),
    );
    return copiedMessages.length;
  }

  @override
  Future<void> deleteMessage(
    int chatId, {
    required int messageId,
  }) async {
    deletedMessages.add(
      DeletedMessage(
        chatId: chatId,
        messageId: messageId,
      ),
    );
  }

  @override
  Future<void> pinMessage(
    int chatId, {
    required int messageId,
    bool disableNotification = true,
  }) async {
    pinnedMessages.add(
      PinnedMessage(
        chatId: chatId,
        messageId: messageId,
        disableNotification: disableNotification,
      ),
    );
  }

  @override
  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  }) async {
    answeredCallbacks.add(
      AnsweredCallback(
        callbackQueryId: callbackQueryId,
        text: text,
        showAlert: showAlert,
      ),
    );
  }
}

final class SentMessage {
  const SentMessage({
    required this.chatId,
    required this.text,
    required this.disableNotification,
    required this.disableWebPagePreview,
    required this.replyMarkup,
    required this.parseMode,
  });

  final int chatId;
  final String text;
  final bool disableNotification;
  final bool disableWebPagePreview;
  final Map<String, Object?>? replyMarkup;
  final String? parseMode;
}

final class CopiedMessage {
  const CopiedMessage({
    required this.toChatId,
    required this.fromChatId,
    required this.messageId,
    required this.disableNotification,
  });

  final int toChatId;
  final int fromChatId;
  final int messageId;
  final bool disableNotification;
}

final class DeletedMessage {
  const DeletedMessage({
    required this.chatId,
    required this.messageId,
  });

  final int chatId;
  final int messageId;
}

final class PinnedMessage {
  const PinnedMessage({
    required this.chatId,
    required this.messageId,
    required this.disableNotification,
  });

  final int chatId;
  final int messageId;
  final bool disableNotification;
}

final class AnsweredCallback {
  const AnsweredCallback({
    required this.callbackQueryId,
    required this.text,
    required this.showAlert,
  });

  final String callbackQueryId;
  final String? text;
  final bool showAlert;
}

final class FakeOnboardingRepository implements OnboardingRepository {
  final Map<int, _FakeOnboardingState> _stateByUserId = <int, _FakeOnboardingState>{};
  final List<PendingWelcomeMessage> readyForDelete = <PendingWelcomeMessage>[];

  @override
  Future<void> close() async {}

  @override
  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  }) async {
    final state = _stateByUserId[userId];
    if (state == null || !state.bonusAvailable || state.bonusConsumed) {
      return false;
    }
    state.bonusConsumed = true;
    return true;
  }

  @override
  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  }) async {
    final state = _stateByUserId[userId];
    if (state == null) {
      return;
    }
    state.bonusConsumed = false;
  }

  @override
  Future<bool> hasStarterBonusAvailable(int userId) async {
    final state = _stateByUserId[userId];
    if (state == null) {
      return false;
    }
    return state.bonusAvailable && !state.bonusConsumed;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  }) async {
    return readyForDelete.take(limit).toList(growable: false);
  }

  @override
  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  }) async {
    final targets = <StarterBonusReminderTarget>[];
    _stateByUserId.forEach((userId, state) {
      if (state.bonusAvailable && !state.bonusConsumed && !state.bonusExpiryReminderSent) {
        targets.add(
          StarterBonusReminderTarget(
            userId: userId,
            expiresAt: now.add(const Duration(hours: 12)),
          ),
        );
      }
    });
    return targets.take(limit).toList(growable: false);
  }

  @override
  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  }) async {
    final state = _stateByUserId[userId];
    if (state == null) {
      return;
    }
    state.pendingWelcome = null;
  }

  @override
  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  }) async {
    final state = _stateByUserId[userId];
    if (state == null) {
      return;
    }
    state.bonusExpiryReminderSent = true;
  }

  @override
  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  }) async {
    return _stateByUserId[userId]?.pendingWelcome;
  }

  @override
  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  }) async {
    _stateByUserId[userId] = _FakeOnboardingState(
      pendingWelcome: PendingWelcomeMessage(
        userId: userId,
        groupChatId: groupChatId,
        welcomeMessageId: welcomeMessageId,
      ),
      bonusAvailable: false,
    );
  }

  void seedUser({
    required int userId,
    bool bonusAvailable = false,
    PendingWelcomeMessage? pendingWelcome,
  }) {
    _stateByUserId[userId] = _FakeOnboardingState(
      pendingWelcome: pendingWelcome,
      bonusAvailable: bonusAvailable,
    );
  }

  @override
  Future<int> getEveryFifthLastNotifiedRewards(int userId) async {
    return _stateByUserId[userId]?.everyFifthLastNotifiedRewards ?? 0;
  }

  @override
  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  }) async {
    final state = _stateByUserId.putIfAbsent(
      userId,
      () => _FakeOnboardingState(
        pendingWelcome: null,
        bonusAvailable: false,
      ),
    );
    state.everyFifthLastNotifiedRewards = rewardsCount;
  }
}

final class _FakeOnboardingState {
  _FakeOnboardingState({
    required this.pendingWelcome,
    required this.bonusAvailable,
  });

  PendingWelcomeMessage? pendingWelcome;
  bool bonusAvailable;
  bool bonusConsumed = false;
  bool bonusExpiryReminderSent = false;
  int everyFifthLastNotifiedRewards = 0;
}

List<String> keyboardTexts(Map<String, Object?>? replyMarkup) {
  if (replyMarkup == null) {
    return const <String>[];
  }
  final keyboard = replyMarkup['keyboard'];
  if (keyboard is! List) {
    return const <String>[];
  }

  final texts = <String>[];
  for (final row in keyboard) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['text'] is String) {
        texts.add(button['text'] as String);
      }
    }
  }
  return texts;
}
