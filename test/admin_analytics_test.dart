import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

void main() {
  group('Admin analytics aggregates', () {
    late Directory dir;
    late SqliteBookingRepository bookings;
    late SqliteOnboardingRepository onboarding;
    late SqliteSubscriptionRepository subscriptions;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('admin_analytics_');
      final path = '${dir.path}/db.sqlite';
      bookings = SqliteBookingRepository(dbPath: path);
      onboarding = SqliteOnboardingRepository(dbPath: path);
      subscriptions = SqliteSubscriptionRepository(dbPath: path);
      await bookings.init();
      await onboarding.init();
      await subscriptions.init();
    });

    tearDown(() async {
      await bookings.close();
      await onboarding.close();
      await subscriptions.close();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('booking analytics counts confirmed and conversion window', () async {
      final now = DateTime.utc(2026, 7, 28, 12);
      final training = TrainingInfo(
        title: 'Силовая',
        startsAt: now.add(const Duration(days: 1)),
        location: 'Двор',
        price: 1000,
      );
      final created = await bookings.createPendingBooking(
        userId: 1,
        userUsername: 'runner',
        training: training,
      );
      await bookings.updateStatus(created.booking.id, BookingStatus.paid);

      final analytics = await bookings.getBookingAnalytics(now: now);
      expect(analytics.totalBookings, 1);
      expect(analytics.statusCounts[BookingStatus.paid.dbValue], 1);
      expect(analytics.upcomingConfirmedCount, 1);
      expect(analytics.uniqueUsersWithConfirmed, 1);
      expect(analytics.confirmedByCategory['trainings'], 1);
      expect(analytics.conversionRate30Days, 1.0);
    });

    test('loyalty analytics reports free bonus bookings and starter pool', () async {
      final now = DateTime.utc(2026, 7, 28, 12);
      await onboarding.ensureStartedUser(11, startedAt: now);
      await onboarding.ensureStartedUser(12, startedAt: now);

      final training = TrainingInfo(
        title: 'Йога',
        startsAt: now.add(const Duration(days: 2)),
        location: 'Зал',
        category: ActivityCategory.yoga,
        price: 0,
      );
      final created = await bookings.createPendingBooking(
        userId: 12,
        training: training,
      );
      await bookings.updateStatus(
        created.booking.id,
        BookingStatus.freeTraining,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
      );

      final starter = await onboarding.getStarterBonusAnalytics();
      final usage = await bookings.getLoyaltyBonusUsageAnalytics(now: now);
      expect(starter.availableCount, 2);
      expect(starter.consumedCount, 0);
      expect(usage.freeByStarterCount, 1);
    });

    test('subscription analytics counts active and pending', () async {
      final now = DateTime.utc(2026, 7, 28, 12);
      await subscriptions.submitPaymentRequest(
        userId: 21,
        userUsername: 'pending_user',
        paymentProofChatId: 1,
        paymentProofMessageId: 2,
        requestedAt: now,
      );
      final analytics = await subscriptions.getSubscriptionAnalytics(now: now);
      expect(analytics.pendingCount, 1);
      expect(analytics.activeCount, 0);
    });
  });
}
