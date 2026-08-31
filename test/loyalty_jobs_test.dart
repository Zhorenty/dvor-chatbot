import 'dart:io';

import 'package:dvor_chatbot/src/application/loyalty_credit_dm.dart';
import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/memory_loyalty_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/loyalty_accrual_job.dart';
import 'package:dvor_chatbot/src/jobs/loyalty_credit_dm_cleanup_job.dart';
import 'package:dvor_chatbot/src/jobs/loyalty_expiry_job.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('expiry job reminds once per expires_at day and can remind after TTL shift', () async {
    var now = DateTime.utc(2026, 3, 1, 12);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    await service.credit(
      userId: 21,
      amount: 200,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g',
      now: now,
    );
    now = now.add(const Duration(days: 38));
    final sender = FakeSender();
    final tmpDir = await Directory.systemTemp.createTemp('loyalty-dedupe-');
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });
    final handle = SqliteDatabaseHandle.open('${tmpDir.path}/jobs.sqlite');
    addTearDown(handle.close);
    final dedupe = JobDedupeRepository(databaseHandle: handle, nowProvider: () => now)
      ..initSchema();
    final job = LoyaltyExpiryJob(
      loyaltyService: service,
      sender: sender,
      templates: const MessageTemplates(),
      jobDedupeRepository: dedupe,
      nowProvider: () => now,
    );

    await job.run();
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, contains('200 ⛰️ сгорят'));
    expect(sender.messages.single.text, isNot(contains('не упусти')));
    expect(sender.messages.single.text, isNot(contains('успей')));

    await job.run();
    expect(sender.messages, hasLength(1));

    now = now.add(const Duration(days: 1));
    await service.touchActivity(21, now: now);
    now = now.add(const Duration(days: 38));
    await job.run();
    expect(sender.messages, hasLength(2));
  });

  test('expiry job burns remaining after 45 days without activity', () async {
    var now = DateTime.utc(2026, 4, 1, 9);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    await service.credit(
      userId: 22,
      amount: 200,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g',
      now: now,
    );
    now = now.add(const Duration(days: 45));
    final sender = FakeSender();
    final job = LoyaltyExpiryJob(
      loyaltyService: service,
      sender: sender,
      templates: const MessageTemplates(),
      nowProvider: () => now,
    );
    await job.run();
    expect((await service.account(22)).remaining, 0);
    expect(sender.messages.single.text, contains('Сгорели 200 ⛰️'));
    await job.run();
    expect(sender.messages, hasLength(1));
  });

  test('accrual credits paid training and skips 100% peaks / card / starter', () async {
    final now = DateTime.utc(2026, 5, 10, 12);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    final bookings = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 1,
          userId: 31,
          title: 'Силовая',
          trainingKey: 'trainings|1',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 2)),
        ),
        fakeBooking(
          id: 2,
          userId: 32,
          title: 'Силовая',
          trainingKey: 'trainings|2',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 2)),
          paymentNote: MessageFormatters.loyaltyPeaksPaymentNoteMarker,
        ),
        fakeBooking(
          id: 3,
          userId: 33,
          title: 'BOXING',
          trainingKey: 'trainings|3',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 2)),
          paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        ),
        fakeBooking(
          id: 4,
          userId: 34,
          title: 'Силовая',
          trainingKey: 'trainings|4',
          status: BookingStatus.paid,
          trainingPrice: 0,
          startsAt: now.subtract(const Duration(hours: 2)),
          paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
        ),
      ];
    final job = LoyaltyAccrualJob(
      loyaltyService: service,
      bookingRepository: bookings,
      onboardingRepository: FakeOnboardingRepository(),
      nowProvider: () => now,
    );
    await job.run();
    expect((await service.account(31)).remaining, 250);
    expect((await service.account(32)).remaining, 0);
    expect((await service.account(33)).remaining, 0);
    expect((await service.account(34)).remaining, 0);
  });

  test('accrual ignores visits older than lookback and stays silent', () async {
    final now = DateTime.utc(2026, 5, 20, 12);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    final bookings = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 50,
          userId: 51,
          title: '🥾 Поход: Карелия',
          trainingKey: 'hikes|50',
          status: BookingStatus.paid,
          trainingPrice: 2500,
          startsAt: now.subtract(const Duration(days: 10)),
        ),
        fakeBooking(
          id: 51,
          userId: 52,
          title: 'Силовая',
          trainingKey: 'trainings|51',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 2)),
        ),
      ];
    final job = LoyaltyAccrualJob(
      loyaltyService: service,
      bookingRepository: bookings,
      onboardingRepository: FakeOnboardingRepository(),
      nowProvider: () => now,
    );
    await job.run();
    expect((await service.account(51)).remaining, 0);
    expect((await service.account(52)).remaining, 250);
  });

  test('referral accrues 1000 only when invitee paid with cash', () async {
    final now = DateTime.utc(2026, 5, 11, 12);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    final onboarding = FakeOnboardingRepository()
      ..referralInviterByInvitee[401] = 400
      ..referralInviterByInvitee[402] = 400;
    final bookings = FakeBookingRepository()
      ..userBookings = <TrainingBooking>[
        fakeBooking(
          id: 10,
          userId: 401,
          title: 'Силовая',
          trainingKey: 'trainings|10',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 1)),
        ),
        fakeBooking(
          id: 11,
          userId: 402,
          title: 'Силовая',
          trainingKey: 'trainings|11',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(hours: 1)),
          paymentNote: MessageFormatters.loyaltyPeaksPaymentNoteMarker,
        ),
      ];
    final job = LoyaltyAccrualJob(
      loyaltyService: service,
      bookingRepository: bookings,
      onboardingRepository: onboarding,
      nowProvider: () => now,
    );
    await job.run();
    expect((await service.account(400)).remaining, LoyaltyMath.referralPeaks);
    expect(await service.hasEntry(LoyaltyKeys.referral(402)), isFalse);
  });

  test('referral accrual skips invitee trainings outside lookback', () async {
    final now = DateTime.utc(2026, 5, 20, 12);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    final onboarding = FakeOnboardingRepository()..referralInviterByInvitee[501] = 500;
    final bookings = FakeBookingRepository()
      ..userBookings = <TrainingBooking>[
        fakeBooking(
          id: 20,
          userId: 501,
          title: 'Силовая',
          trainingKey: 'trainings|20',
          status: BookingStatus.paid,
          trainingPrice: 500,
          startsAt: now.subtract(const Duration(days: 10)),
        ),
      ];
    final job = LoyaltyAccrualJob(
      loyaltyService: service,
      bookingRepository: bookings,
      onboardingRepository: onboarding,
      nowProvider: () => now,
    );
    await job.run();
    expect((await service.account(500)).remaining, 0);
    expect(await service.hasEntry(LoyaltyKeys.referral(501)), isFalse);
  });

  test('credit dm matcher keeps spend and help texts', () {
    const templates = MessageTemplates();
    expect(
      LoyaltyCreditDm.matches(
        templates.loyaltyCredited(
          amount: 250,
          remaining: 250,
          reason: LoyaltyLedgerReason.hike,
        ),
      ),
      isTrue,
    );
    expect(
      LoyaltyCreditDm.matches(
        templates.loyaltyStartCredited(starterBonusAvailable: false),
      ),
      isTrue,
    );
    expect(
      LoyaltyCreditDm.matches(
        templates.loyaltyExpiryReminder(
          remaining: 200,
          expiresAt: DateTime.utc(2026, 6, 1),
        ),
      ),
      isTrue,
    );
    expect(
      LoyaltyCreditDm.matches(templates.loyaltyExpired(burned: 200, remaining: 0)),
      isTrue,
    );
    expect(
      LoyaltyCreditDm.matches(
        templates.loyaltySpendApplied(peaks: 200, remainderRub: 400, coversFully: false),
      ),
      isFalse,
    );
    expect(LoyaltyCreditDm.matches('Живут 45 дней, срок обновляется от записи.'), isFalse);
  });

  test('cleanup job deletes only credit DMs and claims once', () async {
    final log = FakeConversationLogRepository();
    await log.append(
      direction: ConversationDirection.outbound,
      peerUserId: 71,
      chatId: 71,
      telegramMessageId: 101,
      contentType: ConversationContentType.text,
      textPreview: '+200 ⛰️ за поход. Баланс: 200. Живут 45 дней, срок обновляется.',
    );
    await log.append(
      direction: ConversationDirection.outbound,
      peerUserId: 71,
      chatId: 71,
      telegramMessageId: 102,
      contentType: ConversationContentType.text,
      textPreview: 'Списал 200 ⛰️. К оплате: 400 ₽.',
    );
    await log.append(
      direction: ConversationDirection.inbound,
      peerUserId: 71,
      chatId: 71,
      telegramMessageId: 103,
      contentType: ConversationContentType.text,
      textPreview: '+200 ⛰️ за поход.',
    );
    final sender = FakeSender();
    final tmpDir = await Directory.systemTemp.createTemp('loyalty-dm-cleanup-');
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });
    final handle = SqliteDatabaseHandle.open('${tmpDir.path}/jobs.sqlite');
    addTearDown(handle.close);
    final dedupe = JobDedupeRepository(databaseHandle: handle)..initSchema();
    final job = LoyaltyCreditDmCleanupJob(
      conversationLogRepository: log,
      sender: sender,
      jobDedupeRepository: dedupe,
    );
    await job.run();
    expect(sender.deletedMessages, hasLength(1));
    expect(sender.deletedMessages.single.messageId, 101);
    await job.run();
    expect(sender.deletedMessages, hasLength(1));
  });
}
