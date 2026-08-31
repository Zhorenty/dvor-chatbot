import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/memory_loyalty_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late DateTime now;
  late InMemoryLoyaltyRepository loyaltyRepository;
  late LoyaltyService loyaltyService;

  setUp(() {
    now = DateTime.utc(2026, 8, 1, 12);
    loyaltyRepository = InMemoryLoyaltyRepository(nowProvider: () => now);
    loyaltyService = LoyaltyService(repository: loyaltyRepository, nowProvider: () => now);
  });

  PrivateHandlers handlers({
    required FakeSender sender,
    FakeScheduleRepository? schedule,
    FakeBookingRepository? bookings,
    FakeOnboardingRepository? onboarding,
    FakeSubscriptionRepository? subscriptions,
    FakePromoCodeRepository? promo,
  }) {
    return PrivateHandlers(
      sender: sender,
      scheduleRepository: schedule ?? FakeScheduleRepository(const <TrainingInfo>[]),
      bookingRepository: bookings ?? FakeBookingRepository(),
      onboardingRepository: onboarding ?? FakeOnboardingRepository(),
      subscriptionRepository: subscriptions ?? FakeSubscriptionRepository(),
      promoCodeRepository: promo ?? FakePromoCodeRepository(const <PromoCode>[]),
      templates: const MessageTemplates(),
      adminUserIds: const <int>{99},
      adminChatId: -1001,
      loyaltyService: loyaltyService,
      nowProvider: () => now,
    );
  }

  test('/start credits 1000 once; second /start extends TTL only', () async {
    final sender = FakeSender();
    final bot = handlers(sender: sender);

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 70, 'type': 'private'},
      'from': <String, dynamic>{'id': 70},
      'text': '/start',
    });
    expect(
      sender.messages.any((message) => message.text.contains('+1000 ⛰️ за первый старт')),
      isTrue,
    );
    expect((await loyaltyService.account(70)).remaining, 1000);
    final firstExpiry = (await loyaltyService.account(70)).expiresAt();

    sender.messages.clear();
    now = now.add(const Duration(days: 5));
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 70, 'type': 'private'},
      'from': <String, dynamic>{'id': 70},
      'text': '/start',
    });
    expect(
      sender.messages.any((message) => message.text.contains('+1000 ⛰️ за первый старт')),
      isFalse,
    );
    expect((await loyaltyService.account(70)).remaining, 1000);
    final secondExpiry = (await loyaltyService.account(70)).expiresAt();
    expect(secondExpiry!.isAfter(firstExpiry!), isTrue);
  });

  test('creating a booking extends loyalty TTL; opening help does not', () async {
    await loyaltyService.credit(
      userId: 71,
      amount: 200,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g',
      now: now,
    );
    final before = (await loyaltyService.account(71)).expiresAt();
    final sender = FakeSender();
    final bot = handlers(
      sender: sender,
      schedule: FakeScheduleRepository(
        <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая',
            startsAt: DateTime(2026, 8, 10, 19),
            location: 'Hall',
            category: ActivityCategory.trainings,
            price: 500,
          ),
        ],
      ),
    );

    now = now.add(const Duration(days: 2));
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 71, 'type': 'private'},
      'from': <String, dynamic>{'id': 71},
      'text': MessageTemplates.buttonHelp,
    });
    expect((await loyaltyService.account(71)).expiresAt(), before);

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 71, 'type': 'private'},
      'from': <String, dynamic>{'id': 71},
      'text': '/book',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 71, 'type': 'private'},
      'from': <String, dynamic>{'id': 71},
      'text': MessageTemplates.buttonCategoryTrainings,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 71, 'type': 'private'},
      'from': <String, dynamic>{'id': 71},
      'text': '🎯 1. Силовая',
    });
    expect(
      (await loyaltyService.account(71)).expiresAt(),
      now.add(LoyaltyMath.lifetime),
    );
  });

  test('spending peaks can pay a training in full without a receipt', () async {
    await loyaltyService.credit(
      userId: 72,
      amount: 1000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g72',
      now: now,
    );
    final bookings = FakeBookingRepository();
    final sender = FakeSender();
    final bot = handlers(
      sender: sender,
      bookings: bookings,
      schedule: FakeScheduleRepository(
        <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая',
            startsAt: DateTime(2026, 8, 12, 19),
            location: 'Hall',
            category: ActivityCategory.trainings,
            price: 500,
          ),
        ],
      ),
    );

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 72, 'type': 'private'},
      'from': <String, dynamic>{'id': 72},
      'text': '/book',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 72, 'type': 'private'},
      'from': <String, dynamic>{'id': 72},
      'text': MessageTemplates.buttonCategoryTrainings,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 72, 'type': 'private'},
      'from': <String, dynamic>{'id': 72},
      'text': '🎯 1. Силовая',
    });
    expect(
      sender.messages.any((message) => message.text.contains('Списать')),
      isTrue,
    );

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 72, 'type': 'private'},
      'from': <String, dynamic>{'id': 72},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect(bookings.lastUpdatedStatus, BookingStatus.paid);
    expect(bookings.lastUpdatedPaymentNote, MessageFormatters.loyaltyPeaksPaymentNoteMarker);
    expect((await loyaltyService.account(72)).remaining, 0);
  });

  test('outdoor spend is a discount and cannot cover the slot', () async {
    await loyaltyService.credit(
      userId: 73,
      amount: 5000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g73',
      now: now,
    );
    final sender = FakeSender();
    final hikeStarts = DateTime(2026, 9, 1);
    final hikeBot = handlers(
      sender: sender,
      schedule: FakeScheduleRepository(
        const <TrainingInfo>[],
        outdoorItems: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Архыз',
            dateFrom: hikeStarts,
            dateTo: hikeStarts.add(const Duration(hours: 8)),
            location: 'Архыз',
            description: 'Маршрут',
            price: 1500,
          ),
        ],
      ),
    );
    await hikeBot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 73, 'type': 'private'},
      'from': <String, dynamic>{'id': 73},
      'text': '/book',
    });
    await hikeBot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 73, 'type': 'private'},
      'from': <String, dynamic>{'id': 73},
      'text': MessageTemplates.buttonCategoryHikes,
    });
    await hikeBot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 73, 'type': 'private'},
      'from': <String, dynamic>{'id': 73},
      'text': '🎯 1. 🥾 Поход: Архыз',
    });
    await hikeBot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 73, 'type': 'private'},
      'from': <String, dynamic>{'id': 73},
      'text': MessageTemplates.buttonBookTraining,
    });
    await hikeBot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 73, 'type': 'private'},
      'from': <String, dynamic>{'id': 73},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect((await loyaltyService.account(73)).remaining, 5000 - 900);
    expect(
      sender.lastContentMessage.text.toLowerCase(),
      contains('скидка'),
    );
  });

  test('promo then peaks uses discounted remainder; promo_restricted cannot spend', () async {
    await loyaltyService.credit(
      userId: 74,
      amount: 1000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g74',
      now: now,
    );
    final restrictedSender = FakeSender();
    final restricted = handlers(
      sender: restrictedSender,
      schedule: FakeScheduleRepository(
        <TrainingInfo>[
          TrainingInfo(
            title: 'Закрытый слот',
            startsAt: DateTime(2026, 8, 20, 19),
            location: 'Hall',
            category: ActivityCategory.trainings,
            price: 500,
            promoRestricted: true,
          ),
        ],
      ),
    );
    await restricted.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 74, 'type': 'private'},
      'from': <String, dynamic>{'id': 74},
      'text': '/book',
    });
    await restricted.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 74, 'type': 'private'},
      'from': <String, dynamic>{'id': 74},
      'text': MessageTemplates.buttonCategoryTrainings,
    });
    await restricted.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 74, 'type': 'private'},
      'from': <String, dynamic>{'id': 74},
      'text': '🎯 1. Закрытый слот',
    });
    expect(
      restrictedSender.messages.any((message) => message.text.contains('Списать 1000')),
      isFalse,
    );
  });

  test('promo then peaks uses the discounted remainder', () async {
    await loyaltyService.credit(
      userId: 77,
      amount: 1000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g77',
      now: now,
    );
    final bookings = FakeBookingRepository();
    final sender = FakeSender();
    final bot = handlers(
      sender: sender,
      bookings: bookings,
      promo: FakePromoCodeRepository(const <PromoCode>[
        PromoCode(code: 'HALF', discountPercent: 50),
      ]),
      schedule: FakeScheduleRepository(
        <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая',
            startsAt: DateTime(2026, 8, 22, 19),
            location: 'Hall',
            category: ActivityCategory.trainings,
            price: 500,
          ),
        ],
      ),
    );
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': '/book',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': MessageTemplates.buttonCategoryTrainings,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': '🎯 1. Силовая',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': MessageTemplates.buttonEnterPromoCode,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': 'HALF',
    });
    expect(bookings.lastPromoDiscountedPrice, 250);
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 77, 'type': 'private'},
      'from': <String, dynamic>{'id': 77},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect(bookings.lastUpdatedStatus, BookingStatus.paid);
    expect((await loyaltyService.account(77)).remaining, 500);
  });

  test('boxing card 100% peaks activates immediately; partial leftover stays in ₽', () async {
    await loyaltyService.credit(
      userId: 75,
      amount: 7000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g75',
      now: now,
    );
    final subscriptions = FakeSubscriptionRepository();
    final sender = FakeSender();
    final bot = handlers(sender: sender, subscriptions: subscriptions);

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 75, 'type': 'private'},
      'from': <String, dynamic>{'id': 75},
      'text': MessageTemplates.buttonSubscribeApply,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 75, 'type': 'private'},
      'from': <String, dynamic>{'id': 75},
      'text': MessageTemplates.buttonPlanBaza,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 75, 'type': 'private'},
      'from': <String, dynamic>{'id': 75},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect(subscriptions.activateFromLoyaltyCalls, 1);
    expect((await loyaltyService.account(75)).remaining, 0);
    expect(sender.lastContentMessage.text, contains('Карта активна'));
  });

  test('partial boxing card spend leaves a ₽ remainder', () async {
    await loyaltyService.credit(
      userId: 78,
      amount: 2000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g78',
      now: now,
    );
    final subscriptions = FakeSubscriptionRepository();
    final sender = FakeSender();
    final bot = handlers(sender: sender, subscriptions: subscriptions);

    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 78, 'type': 'private'},
      'from': <String, dynamic>{'id': 78},
      'text': MessageTemplates.buttonSubscribeApply,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 78, 'type': 'private'},
      'from': <String, dynamic>{'id': 78},
      'text': MessageTemplates.buttonPlanBaza,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 78, 'type': 'private'},
      'from': <String, dynamic>{'id': 78},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect(subscriptions.activateFromLoyaltyCalls, 0);
    expect((await loyaltyService.account(78)).remaining, 0);
    expect(sender.lastContentMessage.text, contains('К оплате'));
    expect(sender.lastContentMessage.text, contains('2500'));
  });

  test('cancel with refund restores peaks and touches activity', () async {
    await loyaltyService.credit(
      userId: 76,
      amount: 5000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g76',
      now: now,
    );
    final bookings = FakeBookingRepository();
    final sender = FakeSender();
    final hikeStarts = DateTime(2026, 9, 20);
    final bot = handlers(
      sender: sender,
      bookings: bookings,
      schedule: FakeScheduleRepository(
        const <TrainingInfo>[],
        outdoorItems: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Архыз',
            dateFrom: hikeStarts,
            dateTo: hikeStarts.add(const Duration(hours: 8)),
            location: 'Архыз',
            description: 'Маршрут',
            price: 1500,
          ),
        ],
      ),
    );
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': '/book',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': MessageTemplates.buttonCategoryHikes,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': '🎯 1. 🥾 Поход: Архыз',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': MessageTemplates.buttonBookTraining,
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': MessageTemplates.buttonSpendLoyaltyPeaks,
    });
    expect((await loyaltyService.account(76)).remaining, 5000 - 900);

    bookings.cancelResult = BookingActionResult(
      outcome: BookingActionOutcome.success,
      booking: fakeBooking(
        id: 99,
        userId: 76,
        title: '🥾 Поход: Архыз',
        trainingKey: bookings.lastCreatedTraining?.sessionKey,
        status: BookingStatus.cancelled,
        trainingPrice: 1500,
        startsAt: hikeStarts,
      ),
    );

    now = now.add(const Duration(days: 1));
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': '/cancel_booking 99',
    });
    await bot.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 76, 'type': 'private'},
      'from': <String, dynamic>{'id': 76},
      'text': '/cancel_booking_confirm 99',
    });
    expect((await loyaltyService.account(76)).remaining, 5000);
    expect(
      (await loyaltyService.account(76)).expiresAt(),
      now.add(LoyaltyMath.lifetime),
    );
  });
}
