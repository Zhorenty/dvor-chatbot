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
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';

final class FakeScheduleRepository implements TrainingScheduleRepository {
  FakeScheduleRepository(
    this._items, {
    this.yogaItems = const <TrainingInfo>[],
    this.outdoorItems = const <OutdoorActivityInfo>[],
    this.refreshResult = true,
  });

  final List<TrainingInfo> _items;
  final List<TrainingInfo> yogaItems;
  final List<OutdoorActivityInfo> outdoorItems;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) => _items.take(limit).toList();

  @override
  List<TrainingInfo> upcomingYoga({DateTime? now, int limit = 5}) {
    if (yogaItems.isNotEmpty) {
      return yogaItems.take(limit).toList();
    }
    return _items.where((item) => item.category == ActivityCategory.yoga).take(limit).toList();
  }

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
  int? lastUpdatedBookingId;
  BookingStatus? lastUpdatedStatus;
  String? lastUpdatedPaymentNote;
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
  List<TrainingBooking> expiredPending = const <TrainingBooking>[];
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
  ReferralRewardProgress referralProgress = const ReferralRewardProgress(
    qualifiedReferralsCount: 0,
    usedRewardsCount: 0,
  );
  PaymentReviewResult? paymentReviewResult;
  bool throwAdminUpdateConflict = false;
  bool throwAdminCreateConflict = false;
  final Set<String> sentEconomicReports = <String>{};
  int? lastPromoCodeBookingId;
  String? lastPromoCode;
  int? lastPromoDiscountPercent;
  int? lastPromoDiscountedPrice;
  int applyPromoCodeCalls = 0;
  bool promoCodeAlreadyUsed = false;

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
  Future<BookingGroupCreateResult> createPendingBookingGroup({
    required int managerUserId,
    String? managerUsername,
    required TrainingInfo training,
    required List<BookingParticipantDraft> participants,
  }) async {
    createCalls += 1;
    lastCreatedTraining = training;
    lastCreatedUsername = managerUsername;
    final configuredException = createException;
    if (configuredException != null) {
      throw configuredException;
    }
    final groupId = 'pg_fake_$managerUserId';
    final bookings = <TrainingBooking>[
      for (var index = 0; index < participants.length; index++)
        fakeBooking(
          id: 900 + index,
          userId: managerUserId,
          userUsername: managerUsername,
          title: training.title,
          startsAt: training.startsAt,
          location: training.location,
          trainingPrice: training.price,
          paymentGroupId: groupId,
          participantType: participants[index].type,
          participantUsername: participants[index].username,
          participantName: participants[index].name,
        ),
    ];
    return BookingGroupCreateResult(paymentGroupId: groupId, bookings: bookings);
  }

  @override
  Future<List<TrainingBooking>> listBookingsByPaymentGroup(String paymentGroupId) async {
    return userBookings
        .where((booking) => booking.paymentGroupId == paymentGroupId)
        .toList(growable: false);
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
    lastUpdatedBookingId = bookingId;
    lastUpdatedStatus = status;
    lastUpdatedPaymentNote = paymentNote;
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
  Future<TrainingBooking?> applyPromoCode({
    required int bookingId,
    required String code,
    required int discountPercent,
    required int discountedPrice,
  }) async {
    applyPromoCodeCalls += 1;
    lastPromoCodeBookingId = bookingId;
    lastPromoCode = code;
    lastPromoDiscountPercent = discountPercent;
    lastPromoDiscountedPrice = discountedPrice;
    final training = lastCreatedTraining;
    return fakeBooking(
      id: bookingId,
      status: discountPercent >= 100 ? BookingStatus.paid : BookingStatus.pendingPayment,
      title: training?.title ?? 'Training',
      startsAt: training?.startsAt,
      location: training?.location ?? 'Hall',
      trainingPrice: discountedPrice,
      promoCode: code,
      promoDiscountPercent: discountPercent,
    );
  }

  @override
  Future<bool> isPromoCodeUsed(String code, int userId) async => promoCodeAlreadyUsed;

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
  Future<List<TrainingBooking>> expirePendingPaymentBookings({
    required DateTime createdBefore,
    int limit = 50,
  }) async {
    return expiredPending.take(limit).toList(growable: false);
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
                  booking.status == BookingStatus.freeTraining ||
                  booking.status == BookingStatus.partialPaid) &&
              !booking.updatedAt.isBefore(fromInclusive) &&
              booking.updatedAt.isBefore(toExclusive),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listSelfPaidBookingsStartedBetween({
    required DateTime startsFromInclusive,
    required DateTime startsToInclusive,
    int limit = 100,
  }) async {
    return queue
        .where(
          (booking) =>
              booking.participantType == BookingParticipantType.self &&
              (booking.status == BookingStatus.paid ||
                  booking.status == BookingStatus.freeTraining ||
                  booking.status == BookingStatus.partialPaid) &&
              !booking.startsAt.isBefore(startsFromInclusive) &&
              !booking.startsAt.isAfter(startsToInclusive),
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
    int? limit,
  }) async {
    lastAdminListCategory = category;
    lastAdminListArchived = archived;
    if (limit == null) {
      return adminBookings.toList(growable: false);
    }
    return adminBookings.take(limit).toList(growable: false);
  }

  @override
  Future<TrainingBooking> adminCreateBooking({
    int userId = 0,
    required String userUsername,
    required TrainingInfo training,
    required BookingStatus status,
  }) async {
    if (throwAdminCreateConflict) {
      throw const BookingConflictException('conflict');
    }
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
  Future<List<TrainingBooking>> adminSearchBookingsByUsername(
    String username, {
    int limit = 200,
  }) async {
    return queue.where((b) => b.userUsername == username).toList();
  }

  @override
  Future<EveryFifthRewardProgress> getEveryFifthRewardProgress(
    int userId, {
    required DateTime now,
  }) async {
    return everyFifthProgress;
  }

  @override
  Future<ReferralRewardProgress> getReferralRewardProgress(
    int userId, {
    required DateTime now,
  }) async {
    return referralProgress;
  }

  @override
  Future<BookingAnalytics> getBookingAnalytics({required DateTime now}) async {
    return BookingAnalytics(
      generatedAt: now.toUtc(),
      totalBookings: queue.length,
      statusCounts: const <String, int>{},
      createdLast7Days: 0,
      createdLast30Days: 0,
      confirmedLast7Days: 0,
      confirmedLast30Days: 0,
      cancelledLast7Days: 0,
      cancelledLast30Days: 0,
      pendingPaymentCount: 0,
      paymentSubmittedCount: 0,
      upcomingConfirmedCount: 0,
      pastConfirmedCount: 0,
      confirmedByCategory: const <String, int>{},
      createdWithOutcomeLast30Days: 0,
      confirmedAmongOutcomeLast30Days: 0,
      promoCodeBookingsCount: 0,
      uniqueUsersWithConfirmed: 0,
    );
  }

  @override
  Future<LoyaltyBonusUsageAnalytics> getLoyaltyBonusUsageAnalytics({
    required DateTime now,
  }) async {
    return const LoyaltyBonusUsageAnalytics(
      freeByStarterCount: 0,
      freeByReferralCount: 0,
      freeByEveryFifthCount: 0,
      referralAttributionsTotal: 0,
      referralAttributionsLast30Days: 0,
    );
  }
}

final class FakeSubscriptionRepository implements SubscriptionRepository {
  MembershipLevel membershipLevel = MembershipLevel.normal;
  DateTime? membershipActiveUntil;
  List<SubscriptionRequest> pendingRequests = const <SubscriptionRequest>[];
  List<SubscriptionRequest> activeSubscriptions = const <SubscriptionRequest>[];
  SubmitSubscriptionRequestResult submitResult = const SubmitSubscriptionRequestResult(
    outcome: SubmitSubscriptionRequestOutcome.created,
  );
  ReviewSubscriptionRequestResult reviewResult = const ReviewSubscriptionRequestResult(
    outcome: ReviewSubscriptionRequestOutcome.notFound,
  );
  int submitCalls = 0;
  int reviewCalls = 0;
  int cancelCalls = 0;
  CancelSubscriptionResult cancelResult = const CancelSubscriptionResult(
    outcome: CancelSubscriptionOutcome.notFound,
  );

  @override
  Future<void> close() async {}

  @override
  Future<CancelSubscriptionResult> cancelActiveSubscription({
    required int requestId,
    required DateTime cancelledAt,
    String? reason,
    String? comment,
  }) async {
    cancelCalls += 1;
    return cancelResult;
  }

  @override
  Future<SubscriptionMembership> getMembership(
    int userId, {
    required DateTime now,
  }) async {
    return SubscriptionMembership(
      level: membershipLevel,
      activeUntil: membershipActiveUntil,
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<SubscriptionUserSnapshot> getUserSnapshot(
    int userId, {
    required DateTime now,
  }) async {
    return SubscriptionUserSnapshot(
      membership: SubscriptionMembership(
        level: membershipLevel,
        activeUntil: membershipActiveUntil,
      ),
      totalApprovedCount: activeSubscriptions.length,
      latestPending: pendingRequests.isEmpty ? null : pendingRequests.first,
      latestActiveRequest: activeSubscriptions.isEmpty ? null : activeSubscriptions.first,
    );
  }

  @override
  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  }) async {
    return activeSubscriptions.take(limit).toList(growable: false);
  }

  @override
  Future<List<SubscriptionRequest>> listPendingRequests({int limit = 50}) async {
    return pendingRequests.take(limit).toList(growable: false);
  }

  @override
  Future<List<SubscriptionRequest>> listSubscriptionsByFilter({
    required SubscriptionListFilter filter,
    required DateTime now,
    int limit = 200,
  }) async {
    return switch (filter) {
      SubscriptionListFilter.pending => pendingRequests.take(limit).toList(growable: false),
      _ => activeSubscriptions.take(limit).toList(growable: false),
    };
  }

  @override
  Future<List<SubscriptionRequest>> searchSubscriptions(
    String query, {
    required DateTime now,
    int limit = 100,
  }) async {
    final all = <SubscriptionRequest>[...activeSubscriptions, ...pendingRequests];
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequest({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
  }) async {
    reviewCalls += 1;
    return reviewResult;
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequestWithReason({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
    String? reason,
    String? comment,
  }) async {
    reviewCalls += 1;
    return reviewResult;
  }

  @override
  Future<SubmitSubscriptionRequestResult> submitPaymentRequest({
    required int userId,
    String? userUsername,
    String? note,
    required int paymentProofChatId,
    required int paymentProofMessageId,
    required DateTime requestedAt,
  }) async {
    submitCalls += 1;
    return submitResult;
  }

  @override
  Future<List<RenewalReminderTarget>> listRenewalReminderTargets({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <RenewalReminderTarget>[];
  }

  @override
  Future<void> markRenewalReminderSent({
    required int requestId,
    required int daysBefore,
    required DateTime sentAt,
  }) async {}

  @override
  Future<List<SubscriptionRequest>> listExpiredWithoutPromo({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<void> markExpiryPromoSent({
    required int requestId,
    required DateTime sentAt,
  }) async {}

  @override
  Future<SubscriptionAnalytics> getSubscriptionAnalytics({required DateTime now}) async {
    return SubscriptionAnalytics(
      generatedAt: now.toUtc(),
      activeCount: activeSubscriptions.length,
      expiringSoonCount: 0,
      pendingCount: pendingRequests.length,
      cancelledOrRejectedCount: 0,
      approvedTotal: activeSubscriptions.length,
    );
  }
}

final class FakePromoCodeRepository implements PromoCodeRepository {
  FakePromoCodeRepository(
    this.items, {
    this.refreshResult = true,
  });

  List<PromoCode> items;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<PromoCode> all() => items;

  @override
  PromoCode? findByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final item in items) {
      if (item.code.trim().toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> refresh({bool force = false}) async {
    refreshCalls += 1;
    return refreshResult;
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

final class FakeDvorTeamRepository implements DvorTeamRepository {
  FakeDvorTeamRepository({
    Set<String> usernames = const <String>{},
    this.refreshResult = true,
  }) : _usernames = usernames.map(normalizeTelegramUsername).whereType<String>().toSet();

  final Set<String> _usernames;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  Set<String> usernames() => Set<String>.unmodifiable(_usernames);

  @override
  bool containsUsername(String? username) {
    final normalized = normalizeTelegramUsername(username);
    return normalized != null && _usernames.contains(normalized);
  }

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
  String? promoCode,
  int? promoDiscountPercent,
  DateTime? createdAt,
  DateTime? updatedAt,
  BookingParticipantType participantType = BookingParticipantType.self,
  int? managerUserId,
  int? participantUserId,
  String? participantUsername,
  String? participantName,
  String? paymentGroupId,
}) {
  final now = DateTime(2026, 1, 1, 10);
  final resolvedManagerUserId = managerUserId ?? userId;
  final resolvedParticipantUserId =
      participantUserId ?? (participantType == BookingParticipantType.guest ? null : userId);
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
    promoCode: promoCode,
    promoDiscountPercent: promoDiscountPercent,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    managerUserId: resolvedManagerUserId,
    participantType: participantType,
    participantUserId: resolvedParticipantUserId,
    participantUsername: participantUsername ?? userUsername,
    participantName: participantName,
    paymentGroupId: paymentGroupId,
  );
}

final class FakeSender implements MessageSender {
  FakeSender({this.sendDelay});

  final Duration? sendDelay;
  final List<SentMessage> messages = <SentMessage>[];
  final List<CopiedMessage> copiedMessages = <CopiedMessage>[];
  final List<DeletedMessage> deletedMessages = <DeletedMessage>[];
  final List<BannedMember> bannedMembers = <BannedMember>[];
  final List<PinnedMessage> pinnedMessages = <PinnedMessage>[];
  final List<AnsweredCallback> answeredCallbacks = <AnsweredCallback>[];
  final List<EditedReplyMarkup> editedReplyMarkups = <EditedReplyMarkup>[];
  final Map<int, Exception> sendMessageFailuresByChatId = <int, Exception>{};

  static const String navHintText = 'Навигация 👇';

  SentMessage get lastContentMessage {
    if (messages.isEmpty) {
      throw StateError('No messages sent');
    }
    final last = messages.last;
    if (last.text == navHintText && messages.length >= 2) {
      return messages[messages.length - 2];
    }
    return last;
  }

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) async {
    final delay = sendDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    final failure = sendMessageFailuresByChatId[chatId];
    if (failure != null) {
      throw failure;
    }
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
  Future<void> banChatMember(
    int chatId, {
    required int userId,
    bool revokeMessages = true,
  }) async {
    bannedMembers.add(
      BannedMember(
        chatId: chatId,
        userId: userId,
        revokeMessages: revokeMessages,
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

  @override
  Future<void> editMessageReplyMarkup(
    int chatId, {
    required int messageId,
    Map<String, Object?>? replyMarkup,
  }) async {
    editedReplyMarkups.add(
      EditedReplyMarkup(
        chatId: chatId,
        messageId: messageId,
        replyMarkup: replyMarkup,
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

final class BannedMember {
  const BannedMember({
    required this.chatId,
    required this.userId,
    required this.revokeMessages,
  });

  final int chatId;
  final int userId;
  final bool revokeMessages;
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

final class EditedReplyMarkup {
  const EditedReplyMarkup({
    required this.chatId,
    required this.messageId,
    required this.replyMarkup,
  });

  final int chatId;
  final int messageId;
  final Map<String, Object?>? replyMarkup;
}

final class FakeOnboardingRepository implements OnboardingRepository {
  final Map<int, _FakeOnboardingState> _stateByUserId = <int, _FakeOnboardingState>{};
  final List<PendingWelcomeMessage> readyForDelete = <PendingWelcomeMessage>[];
  final Map<int, int> referralInviterByInvitee = <int, int>{};
  final Set<String> sentNudgeKeys = <String>{};
  final Set<int> feedbackRequestBookingIds = <int>{};
  final Set<int> feedbackSubmittedBookingIds = <int>{};

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
    await ensureStartedUser(userId, startedAt: startedAt);
    return _stateByUserId[userId]?.pendingWelcome;
  }

  @override
  Future<OnboardingUserState> ensureStartedUser(
    int userId, {
    required DateTime startedAt,
    OnboardingEntryType? entryType,
  }) async {
    final state = _stateByUserId.putIfAbsent(
      userId,
      () => _FakeOnboardingState(
        pendingWelcome: null,
        bonusAvailable: false,
        phase: OnboardingPhase.phase1Quiz,
        step: OnboardingStep.welcome,
        entryType: entryType ?? OnboardingEntryType.cold,
        onboardingStartedAt: startedAt,
      ),
    );
    state.startedAt ??= startedAt;
    state.onboardingStartedAt ??= startedAt;
    if (state.phase == null) {
      state.phase = OnboardingPhase.phase1Quiz;
      state.step = OnboardingStep.welcome;
      state.entryType ??= entryType ?? OnboardingEntryType.cold;
    }
    return _toState(userId, state);
  }

  @override
  Future<OnboardingUserState?> getOnboardingState(int userId) async {
    final state = _stateByUserId[userId];
    if (state == null) {
      return null;
    }
    return _toState(userId, state);
  }

  @override
  Future<void> updateOnboardingProgress({
    required int userId,
    OnboardingPhase? phase,
    OnboardingStep? step,
    OnboardingQuizGoal? quizGoal,
    OnboardingQuizExperience? quizExperience,
    OnboardingTrack? selectedTrack,
    OnboardingEntryType? entryType,
    DateTime? onboardingStartedAt,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
  }) async {
    final state = _stateByUserId.putIfAbsent(
      userId,
      () => _FakeOnboardingState(
        pendingWelcome: null,
        bonusAvailable: false,
      ),
    );
    if (phase != null) {
      state.phase = phase;
    }
    if (step != null) {
      state.step = step;
    }
    if (quizGoal != null) {
      state.quizGoal = quizGoal;
    }
    if (quizExperience != null) {
      state.quizExperience = quizExperience;
    }
    if (selectedTrack != null) {
      state.selectedTrack = selectedTrack;
    }
    if (entryType != null) {
      state.entryType = entryType;
    }
    if (onboardingStartedAt != null) {
      state.onboardingStartedAt = onboardingStartedAt;
    }
    if (clearSnooze) {
      state.snoozeUntil = null;
    } else if (snoozeUntil != null) {
      state.snoozeUntil = snoozeUntil;
    }
  }

  @override
  Future<bool> tryMarkActivation(
    int userId, {
    required DateTime activatedAt,
  }) async {
    final state = _stateByUserId[userId];
    if (state == null ||
        state.phase == OnboardingPhase.legacySkipped ||
        state.activationAt != null) {
      return false;
    }
    state.activationAt = activatedAt;
    state.phase = OnboardingPhase.phase3Integration;
    return true;
  }

  @override
  Future<bool> hasNudgeBeenSent({
    required int userId,
    required String nudgeKey,
  }) async {
    return sentNudgeKeys.contains('$userId::$nudgeKey');
  }

  @override
  Future<void> recordNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
    OnboardingPhase? phase,
    OnboardingStep? step,
  }) async {
    sentNudgeKeys.add('$userId::$nudgeKey');
    final state = _stateByUserId[userId];
    if (state != null) {
      state.lastNudgeAt = sentAt;
    }
  }

  @override
  Future<List<OnboardingNudgeCandidate>> listOnboardingNudgeCandidates({
    required DateTime now,
    int limit = 100,
  }) async {
    final result = <OnboardingNudgeCandidate>[];
    _stateByUserId.forEach((userId, state) {
      if (state.phase == null ||
          state.phase == OnboardingPhase.legacySkipped ||
          state.phase == OnboardingPhase.completed ||
          state.onboardingStartedAt == null) {
        return;
      }
      if (state.snoozeUntil != null && state.snoozeUntil!.isAfter(now.toUtc())) {
        return;
      }
      result.add(
        OnboardingNudgeCandidate(
          userId: userId,
          phase: state.phase!,
          step: state.step,
          onboardingStartedAt: state.onboardingStartedAt!,
          quizGoal: state.quizGoal,
          selectedTrack: state.selectedTrack,
          activationAt: state.activationAt,
          lastNudgeAt: state.lastNudgeAt,
          snoozeUntil: state.snoozeUntil,
        ),
      );
    });
    return result.take(limit).toList(growable: false);
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
    OnboardingPhase phase = OnboardingPhase.legacySkipped,
    OnboardingStep? step,
    DateTime? onboardingStartedAt,
    DateTime? activationAt,
  }) {
    _stateByUserId[userId] = _FakeOnboardingState(
      pendingWelcome: pendingWelcome,
      bonusAvailable: bonusAvailable,
      phase: phase,
      step: step,
      onboardingStartedAt: onboardingStartedAt,
      activationAt: activationAt,
      startedAt: onboardingStartedAt ?? DateTime.now().toUtc(),
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
        phase: OnboardingPhase.legacySkipped,
      ),
    );
    state.everyFifthLastNotifiedRewards = rewardsCount;
  }

  @override
  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  }) async {
    if (inviteeUserId <= 0 || inviterUserId <= 0 || inviteeUserId == inviterUserId) {
      return;
    }
    referralInviterByInvitee.putIfAbsent(inviteeUserId, () => inviterUserId);
  }

  @override
  Future<List<int>> getAllStartedUserIds() async {
    return _stateByUserId.keys.toList();
  }

  @override
  Future<bool> hasTrainingFeedbackRequest(int bookingId) async {
    return feedbackRequestBookingIds.contains(bookingId);
  }

  @override
  Future<void> recordTrainingFeedbackRequest({
    required int bookingId,
    required int userId,
    required String sessionKey,
    required String trainingTitle,
    required DateTime sentAt,
  }) async {
    feedbackRequestBookingIds.add(bookingId);
  }

  @override
  Future<void> submitTrainingFeedback({
    required int bookingId,
    required String sessionKey,
    required TrainingFeedbackRating rating,
    required DateTime submittedAt,
    String? comment,
  }) async {
    feedbackSubmittedBookingIds.add(bookingId);
  }

  @override
  Future<TrainingFeedbackRequest?> getTrainingFeedbackRequest(int bookingId) async {
    if (!feedbackRequestBookingIds.contains(bookingId)) {
      return null;
    }
    return TrainingFeedbackRequest(
      bookingId: bookingId,
      userId: 0,
      sessionKey: 'session',
      trainingTitle: 'Training',
      sentAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<bool> hasTrainingFeedback(int bookingId) async {
    return feedbackSubmittedBookingIds.contains(bookingId);
  }

  @override
  Future<FunnelAnalytics> getFunnelAnalytics({
    required DateTime now,
    int recentCommentsLimit = 10,
    int topSessionsLimit = 8,
  }) async {
    final started = _stateByUserId.values.where((s) => s.startedAt != null).length;
    final legacy =
        _stateByUserId.values.where((s) => s.phase == OnboardingPhase.legacySkipped).length;
    final funnel = _stateByUserId.values
        .where(
          (s) => s.startedAt != null && s.phase != null && s.phase != OnboardingPhase.legacySkipped,
        )
        .length;
    final activations = _stateByUserId.values.where((s) => s.activationAt != null).length;
    final phaseCounts = <String, int>{};
    for (final state in _stateByUserId.values) {
      final phase = state.phase;
      if (phase == null) {
        continue;
      }
      phaseCounts.update(phase.storageValue, (value) => value + 1, ifAbsent: () => 1);
    }
    final nudgeCounts = <String, int>{};
    for (final key in sentNudgeKeys) {
      final nudgeKey = key.contains('::') ? key.split('::').last : key;
      nudgeCounts.update(nudgeKey, (value) => value + 1, ifAbsent: () => 1);
    }
    return FunnelAnalytics(
      generatedAt: now.toUtc(),
      startedUsersTotal: started,
      legacyUsers: legacy,
      funnelUsers: funnel,
      completedUsers:
          _stateByUserId.values.where((s) => s.phase == OnboardingPhase.completed).length,
      phaseCounts: phaseCounts,
      entryTypeCounts: const <String, int>{},
      quizGoalCounts: const <String, int>{},
      quizExperienceCounts: const <String, int>{},
      trackCounts: const <String, int>{},
      startedLast7Days: started,
      startedLast30Days: started,
      activationsTotal: activations,
      activationsLast7Days: activations,
      activationsLast30Days: activations,
      activationRate21Days: funnel == 0 ? null : activations / funnel,
      avgTimeToValueDays: null,
      snoozeActiveNow: 0,
      nudgeKeyCounts: nudgeCounts,
      feedbackRequestsSent: feedbackRequestBookingIds.length,
      feedbackResponses: feedbackSubmittedBookingIds.length,
      feedbackSkipped: 0,
      feedbackRatingCounts: const <String, int>{},
      feedbackCommentsCount: 0,
      recentFeedbackComments: const <RecentFeedbackComment>[],
      topFeedbackSessions: const <FeedbackSessionSummary>[],
    );
  }

  @override
  Future<StarterBonusAnalytics> getStarterBonusAnalytics() async {
    return const StarterBonusAnalytics(availableCount: 0, consumedCount: 0);
  }

  OnboardingUserState _toState(int userId, _FakeOnboardingState state) {
    return OnboardingUserState(
      userId: userId,
      phase: state.phase,
      step: state.step,
      quizGoal: state.quizGoal,
      quizExperience: state.quizExperience,
      selectedTrack: state.selectedTrack,
      activationAt: state.activationAt,
      onboardingStartedAt: state.onboardingStartedAt,
      lastNudgeAt: state.lastNudgeAt,
      snoozeUntil: state.snoozeUntil,
      entryType: state.entryType,
      startedAt: state.startedAt,
    );
  }
}

final class _FakeOnboardingState {
  _FakeOnboardingState({
    required this.pendingWelcome,
    required this.bonusAvailable,
    this.phase,
    this.step,
    this.activationAt,
    this.onboardingStartedAt,
    this.entryType,
    this.startedAt,
  });

  PendingWelcomeMessage? pendingWelcome;
  bool bonusAvailable;
  bool bonusConsumed = false;
  bool bonusExpiryReminderSent = false;
  int everyFifthLastNotifiedRewards = 0;
  OnboardingPhase? phase;
  OnboardingStep? step;
  OnboardingQuizGoal? quizGoal;
  OnboardingQuizExperience? quizExperience;
  OnboardingTrack? selectedTrack;
  DateTime? activationAt;
  DateTime? onboardingStartedAt;
  DateTime? lastNudgeAt;
  DateTime? snoozeUntil;
  OnboardingEntryType? entryType;
  DateTime? startedAt;
}

final class FakeConversationLogRepository implements ConversationLogRepository {
  final List<ConversationLogEntry> entries = <ConversationLogEntry>[];
  final Map<int, String?> users = <int, String?>{};
  int _nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> upsertTelegramUser({
    required int userId,
    String? username,
  }) async {
    final normalized = normalizeTelegramUsername(username);
    users[userId] = normalized ?? users[userId];
  }

  @override
  Future<void> append({
    required ConversationDirection direction,
    required int peerUserId,
    String? peerUsername,
    required int chatId,
    int? telegramMessageId,
    required ConversationContentType contentType,
    String? textPreview,
  }) async {
    final normalized = normalizeTelegramUsername(peerUsername);
    await upsertTelegramUser(userId: peerUserId, username: normalized);
    entries.add(
      ConversationLogEntry(
        id: _nextId++,
        occurredAt: DateTime.now(),
        direction: direction,
        peerUserId: peerUserId,
        peerUsername: normalized ?? users[peerUserId],
        chatId: chatId,
        telegramMessageId: telegramMessageId,
        contentType: contentType,
        textPreview: textPreview,
      ),
    );
  }

  @override
  Future<List<ConversationLogEntry>> recentActions({
    int limit = 40,
    Set<int> excludePeerIds = const <int>{},
  }) async {
    final filtered = entries.where((entry) => !excludePeerIds.contains(entry.peerUserId)).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<List<ConversationLogEntry>> dialogForUserId(
    int userId, {
    int limit = 50,
  }) async {
    final filtered = entries.where((entry) => entry.peerUserId == userId).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(filtered.length - limit);
  }

  @override
  Future<int?> resolveUserIdByUsername(String username) async {
    final normalized = normalizeTelegramUsername(username);
    if (normalized == null) {
      return null;
    }
    for (final entry in users.entries) {
      if (entry.value == normalized) {
        return entry.key;
      }
    }
    for (final entry in entries.reversed) {
      if (entry.peerUsername == normalized) {
        return entry.peerUserId;
      }
    }
    return null;
  }
}

List<String> keyboardTexts(Map<String, Object?>? replyMarkup) {
  if (replyMarkup == null) {
    return const <String>[];
  }
  final texts = <String>[];
  final keyboard = replyMarkup['keyboard'];
  if (keyboard is List) {
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
  }
  final inline = replyMarkup['inline_keyboard'];
  if (inline is List) {
    for (final row in inline) {
      if (row is! List) {
        continue;
      }
      for (final button in row) {
        if (button is Map && button['text'] is String) {
          texts.add(button['text'] as String);
        }
      }
    }
  }
  return texts;
}
