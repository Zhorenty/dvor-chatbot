import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

final class EveryFifthRewardProgress {
  const EveryFifthRewardProgress({
    required this.qualifiedTrainingsCount,
    required this.usedRewardsCount,
  });

  final int qualifiedTrainingsCount;
  final int usedRewardsCount;

  int get earnedRewardsCount => qualifiedTrainingsCount ~/ 4;
  int get availableRewardsCount => earnedRewardsCount - usedRewardsCount;
}

final class BookingConflictException implements Exception {
  const BookingConflictException(this.message);

  final String message;

  @override
  String toString() => 'BookingConflictException: $message';
}

final class BookingParticipantsLimitExceededException implements Exception {
  const BookingParticipantsLimitExceededException(this.message);

  final String message;

  @override
  String toString() => 'BookingParticipantsLimitExceededException: $message';
}

enum PaymentReviewOutcome {
  success,
  notFound,
  invalidStatus,
}

final class PaymentReviewResult {
  const PaymentReviewResult({
    required this.outcome,
    this.booking,
  });

  final PaymentReviewOutcome outcome;
  final TrainingBooking? booking;
}

abstract interface class BookingRepository {
  Future<void> init();

  Future<void> close();

  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    String? userUsername,
    required TrainingInfo training,
  });

  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10});

  Future<BookingActionResult> cancelBooking({
    required int userId,
    required int bookingId,
  });

  Future<BookingRescheduleResult> rescheduleBooking({
    required int userId,
    required int bookingId,
    required TrainingInfo training,
  });

  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    int? bookingId,
    String? note,
    int? paymentProofChatId,
    int? paymentProofMessageId,
  });

  Future<List<TrainingBooking>> listByStatus(
    BookingStatus status, {
    int limit = 20,
  });

  Future<List<TrainingBooking>> listByTrainingKeys(
    Set<String> trainingKeys, {
    int limit = 200,
    bool includeCancelled = false,
  });

  Future<TrainingBooking?> updateStatus(
    int bookingId,
    BookingStatus status, {
    String? paymentNote,
  });

  Future<PaymentReviewResult> reviewSubmittedPayment({
    required int bookingId,
    required BookingStatus status,
  });

  Future<List<TrainingBooking>> listPendingPaymentForReminder({
    required DateTime createdBefore,
    required DateTime remindedBefore,
    int limit = 20,
  });

  Future<void> markReminderSent(int bookingId);

  Future<List<TrainingBooking>> listPaidBookingsInRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
    int limit = 5000,
  });

  Future<bool> tryMarkEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime sentAt,
  });

  Future<void> rollbackEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  Future<({int active, int archived})> adminCountBySegment();

  Future<List<TrainingBooking>> adminListBookings({
    required ActivityCategory category,
    required bool archived,
    int? limit,
  });

  Future<TrainingBooking> adminCreateBooking({
    int userId = 0,
    required String userUsername,
    required TrainingInfo training,
    required BookingStatus status,
  });

  Future<TrainingBooking?> adminUpdateBooking({
    required int bookingId,
    String? userUsername,
    TrainingInfo? training,
    BookingStatus? status,
  });

  Future<TrainingBooking?> adminArchiveBooking(int bookingId);

  Future<EveryFifthRewardProgress> getEveryFifthRewardProgress(
    int userId, {
    required DateTime now,
  });
}
