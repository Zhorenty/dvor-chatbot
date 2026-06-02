import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
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
  List<TrainingBooking> queue = const <TrainingBooking>[];
  List<TrainingBooking> bookingsByTrainingKey = const <TrainingBooking>[];
  TrainingBooking? submitResult;
  TrainingInfo? lastCreatedTraining;
  String? lastCreatedUsername;
  List<TrainingBooking> pendingForReminder = const <TrainingBooking>[];
  int remindersMarked = 0;

  @override
  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    String? userUsername,
    required TrainingInfo training,
  }) async {
    createCalls += 1;
    lastCreatedTraining = training;
    lastCreatedUsername = userUsername;
    return BookingCreateResult(
      booking: fakeBooking(
        id: 99,
        userId: userId,
        userUsername: userUsername,
        title: training.title,
        startsAt: training.startsAt,
        location: training.location,
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
  }) async {
    return bookingsByTrainingKey
        .where((booking) => trainingKeys.contains(booking.trainingKey))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10}) async {
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

  @override
  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    String? note,
    int? paymentProofChatId,
    int? paymentProofMessageId,
  }) async {
    submitCalls += 1;
    return submitResult;
  }

  @override
  Future<TrainingBooking?> updateStatus(int bookingId, BookingStatus status) async {
    return fakeBooking(id: bookingId, status: status);
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
    paymentNote: null,
    paymentProofChatId: paymentProofChatId,
    paymentProofMessageId: paymentProofMessageId,
    createdAt: now,
    updatedAt: now,
  );
}

final class FakeSender implements MessageSender {
  final List<SentMessage> messages = <SentMessage>[];
  final List<CopiedMessage> copiedMessages = <CopiedMessage>[];
  final List<DeletedMessage> deletedMessages = <DeletedMessage>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) async {
    messages.add(
      SentMessage(
        chatId: chatId,
        text: text,
        disableNotification: disableNotification,
        replyMarkup: replyMarkup,
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
}

final class SentMessage {
  const SentMessage({
    required this.chatId,
    required this.text,
    required this.disableNotification,
    required this.replyMarkup,
  });

  final int chatId;
  final String text;
  final bool disableNotification;
  final Map<String, Object?>? replyMarkup;
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
}

final class _FakeOnboardingState {
  _FakeOnboardingState({
    required this.pendingWelcome,
    required this.bonusAvailable,
  });

  PendingWelcomeMessage? pendingWelcome;
  bool bonusAvailable;
  bool bonusConsumed = false;
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
