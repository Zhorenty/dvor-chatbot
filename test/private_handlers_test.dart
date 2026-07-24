import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/telegram_fixtures.dart';

typedef _FakeScheduleRepository = FakeScheduleRepository;
typedef _FakeBookingRepository = FakeBookingRepository;
typedef _FakeOnboardingRepository = FakeOnboardingRepository;
typedef _FakeSubscriptionRepository = FakeSubscriptionRepository;
typedef _FakeSender = FakeSender;
typedef _FakeTrainerDirectoryRepository = FakeTrainerDirectoryRepository;
typedef _FakePromoCodeRepository = FakePromoCodeRepository;

TrainingBooking _booking({
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
  String? paymentNote,
  DateTime? updatedAt,
}) {
  return fakeBooking(
    id: id,
    userId: userId,
    userUsername: userUsername,
    paymentProofChatId: paymentProofChatId,
    paymentProofMessageId: paymentProofMessageId,
    trainingKey: trainingKey,
    title: title,
    startsAt: startsAt,
    location: location,
    status: status,
    paymentNote: paymentNote,
    updatedAt: updatedAt,
  );
}

List<String> _keyboardTexts(Map<String, Object?>? replyMarkup) => keyboardTexts(replyMarkup);

void main() {
  group('PrivateHandlers', () {
    test('handles /start command in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 11, 'type': 'private'},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 11);
      expect(sender.messages.single.text, contains('Добро пожаловать в DVOR'));
      expect(sender.messages.single.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.single.text, contains('Группа DVOR'));
      expect(sender.messages.single.replyMarkup, isNotNull);
      expect(sender.pinnedMessages, hasLength(1));
      expect(sender.pinnedMessages.single.chatId, 11);
      expect(sender.pinnedMessages.single.messageId, 1);
    });

    test('deletes group welcome message when user sends /start', () async {
      final sender = _FakeSender();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(
          userId: 111,
          pendingWelcome: const PendingWelcomeMessage(
            userId: 111,
            groupChatId: -100900,
            welcomeMessageId: 45,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 111, 'type': 'private'},
        'from': <String, dynamic>{'id': 111},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.deletedMessages, hasLength(1));
      expect(sender.deletedMessages.single.chatId, -100900);
      expect(sender.deletedMessages.single.messageId, 45);
    });

    test('shows starter bonus onboarding offer on /start when available', () async {
      final sender = _FakeSender();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 112, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 112, 'type': 'private'},
        'from': <String, dynamic>{'id': 112},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Добро пожаловать в DVOR'));
      expect(sender.messages.first.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.last.text, contains('бесплатная тренировка'));
      expect(sender.messages.last.text, contains('Записаться'));
      expect(sender.messages.last.text, contains(MessageTemplates.buttonUseStarterBonus));
      expect(sender.pinnedMessages, hasLength(1));
      expect(sender.pinnedMessages.single.chatId, 112);
      expect(sender.pinnedMessages.single.messageId, 1);
    });

    test('stores referral attribution from /start payload', () async {
      final sender = _FakeSender();
      final onboardingRepository = _FakeOnboardingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 112, 'type': 'private'},
        'from': <String, dynamic>{'id': 112},
        'text': '/start ref_991',
      });

      expect(handled, isTrue);
      expect(onboardingRepository.referralInviterByInvitee[112], 991);
    });

    test('shows only admin buttons in private menu for admin users', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9100},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonPaymentsQueue));
      expect(buttons, contains(MessageTemplates.buttonManageBookings));
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
      expect(buttons, contains(MessageTemplates.buttonBroadcast));
      expect(buttons, contains(MessageTemplates.buttonAdminTools));
      expect(buttons, isNot(contains(MessageTemplates.buttonRefreshSchedule)));
      expect(buttons, isNot(contains(MessageTemplates.buttonEconomicSummary)));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubscriptionsAdmin)));
      expect(buttons, isNot(contains(MessageTemplates.buttonNoblesList)));
      expect(buttons, isNot(contains(MessageTemplates.buttonAdminUserSearch)));
      expect(buttons, isNot(contains(MessageTemplates.buttonDvorXFrank)));
      expect(buttons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonBookTraining)));
      expect(buttons, isNot(contains(MessageTemplates.buttonCoachingStaff)));
      expect(buttons, isNot(contains(MessageTemplates.buttonProfile)));
      expect(buttons, isNot(contains(MessageTemplates.buttonHelp)));
    });

    test('opens admin tools and client menu with return to admin', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9100},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonAdminTools,
      });
      final toolsButtons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(toolsButtons, contains(MessageTemplates.buttonRefreshSchedule));
      expect(toolsButtons, contains(MessageTemplates.buttonEconomicSummary));
      expect(toolsButtons, contains(MessageTemplates.buttonSubscriptionsAdmin));
      expect(toolsButtons, contains(MessageTemplates.buttonNoblesList));
      expect(toolsButtons, contains(MessageTemplates.buttonAdminUserSearch));
      expect(toolsButtons, contains(MessageTemplates.buttonClientMenu));
      expect(toolsButtons, isNot(contains(MessageTemplates.buttonParticipantsList)));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonClientMenu,
      });
      final clientButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(clientButtons, contains(MessageTemplates.buttonBookTraining));
      expect(clientButtons, contains(MessageTemplates.buttonProfile));
      expect(clientButtons, contains(MessageTemplates.buttonAdminMenu));
      expect(clientButtons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(clientButtons, isNot(contains(MessageTemplates.buttonPaymentsQueue)));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonAdminMenu,
      });
      final adminButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(adminButtons, contains(MessageTemplates.buttonAdminTools));
      expect(adminButtons, contains(MessageTemplates.buttonPaymentsQueue));
      expect(adminButtons, isNot(contains(MessageTemplates.buttonBookTraining)));
    });

    test('opens subscriptions filters directly for admin', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9100},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonSubscriptionsAdmin,
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonSubscriptionsFilterActive));
      expect(buttons, contains(MessageTemplates.buttonSubscriptionsFilterPending));
      expect(buttons, contains(MessageTemplates.buttonSubscriptionsSearch));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubscriptionsList)));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubscribersManagement)));
    });

    test('shows coaching staff button for regular users in private menu', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9101, 'type': 'private'},
        'from': <String, dynamic>{'id': 9101},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      // TODO(dvor-x-frank): вернуть expect(buttons.first, MessageTemplates.buttonDvorXFrank).
      expect(buttons, isNot(contains(MessageTemplates.buttonDvorXFrank)));
      expect(buttons, contains(MessageTemplates.buttonCoachingStaff));
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, contains(MessageTemplates.buttonBookFriend));
      expect(buttons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(buttons, contains(MessageTemplates.buttonProfile));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubscription)));
    });

    // TODO(dvor-x-frank): вернуть тест после включения промо-кнопки в меню.
    // test('opens DVOR x FRANK promo teaser for regular users', () async {
    //   final sender = _FakeSender();
    //   final handlers = PrivateHandlers(
    //     sender: sender,
    //     scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
    //     bookingRepository: _FakeBookingRepository(),
    //     templates: const MessageTemplates(),
    //     adminUserIds: const <int>{},
    //   );
    //
    //   final handled = await handlers.handle(<String, dynamic>{
    //     'chat': <String, dynamic>{'id': 9101, 'type': 'private'},
    //     'from': <String, dynamic>{'id': 9101},
    //     'text': MessageTemplates.buttonDvorXFrank,
    //   });
    //
    //   expect(handled, isTrue);
    //   expect(sender.messages.single.text, contains('DVOR x FRANK by БАСТА'));
    //   expect(sender.messages.single.text, contains('Здесь скоро будет что-то интересное'));
    //   expect(sender.messages.single.parseMode, 'HTML');
    //   expect(
    //     _keyboardTexts(sender.messages.single.replyMarkup),
    //     contains(MessageTemplates.buttonDvorXFrank),
    //   );
    // });

    test('shows participants button in private menu for yoga trainer role', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 857655217, 'type': 'private'},
        'from': <String, dynamic>{'id': 857655217},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, contains(MessageTemplates.buttonBookFriend));
      expect(buttons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubscription)));
      expect(buttons, isNot(contains(MessageTemplates.buttonRefreshSchedule)));
      expect(buttons, isNot(contains(MessageTemplates.buttonPaymentsQueue)));
      expect(buttons, isNot(contains(MessageTemplates.buttonEconomicSummary)));
      expect(buttons, isNot(contains(MessageTemplates.buttonNoblesList)));
      expect(buttons, isNot(contains(MessageTemplates.buttonManageBookings)));
    });

    test('opens subscription overview and allows applying for normal user', () async {
      final sender = _FakeSender();
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.normal;
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9102, 'type': 'private'},
        'from': <String, dynamic>{'id': 9102},
        'text': MessageTemplates.buttonSubscription,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('Абонемент DVOR'));
      expect(sender.messages.single.text, contains('Оформить'));
      expect(_keyboardTexts(sender.messages.single.replyMarkup),
          contains(MessageTemplates.buttonSubscribeApply));
    });

    test('shows renewal call-to-action for active PRO subscription', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(
            id: 8101,
            userId: 9103,
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
            updatedAt: DateTime(2026, 7, 10, 10),
          ),
          _booking(
            id: 8102,
            userId: 9103,
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
            updatedAt: DateTime(2026, 7, 11, 10),
          ),
        ];
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.pro
        ..membershipActiveUntil = DateTime(2026, 8, 1, 12);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9103, 'type': 'private'},
        'from': <String, dynamic>{'id': 9103},
        'text': MessageTemplates.buttonSubscription,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text,
          contains('Осталось тренировок в текущем PRO:</b> <b>6/8</b>'));
      expect(sender.messages.single.text, contains('Продление доступно уже сейчас'));
      expect(
        _keyboardTexts(sender.messages.single.replyMarkup),
        contains(MessageTemplates.buttonRenewSubscription),
      );
    });

    test('submits subscription payment request after proof file', () async {
      final sender = _FakeSender();
      final request = SubscriptionRequest(
        id: 9001,
        userId: 9201,
        userUsername: 'sub_user',
        status: SubscriptionRequestStatus.paymentSubmitted,
        createdAt: DateTime(2026, 7, 1, 12),
        updatedAt: DateTime(2026, 7, 1, 12),
        paymentProofChatId: 9201,
        paymentProofMessageId: 44,
      );
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.normal
        ..submitResult = SubmitSubscriptionRequestResult(
          outcome: SubmitSubscriptionRequestOutcome.created,
          request: request,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100500,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9201, 'type': 'private'},
        'from': <String, dynamic>{'id': 9201, 'username': 'sub_user'},
        'text': MessageTemplates.buttonSubscribeApply,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'message_id': 44,
          'chat': <String, dynamic>{'id': 9201, 'type': 'private'},
          'from': <String, dynamic>{'id': 9201, 'username': 'sub_user'},
          'photo': <Map<String, Object?>>[
            <String, Object?>{'file_id': 'photo_1'}
          ],
        },
      });

      expect(handled, isTrue);
      expect(subscriptionRepository.submitCalls, 1);
      expect(sender.messages.last.text, contains('Заявка на абонемент отправлена'));
      expect(sender.messages.any((item) => item.chatId == -100500), isTrue);
    });

    test('back from subscription payment keeps current PRO status', () async {
      final sender = _FakeSender();
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.pro
        ..membershipActiveUntil = DateTime(2026, 8, 1, 12);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9301, 'type': 'private'},
        'from': <String, dynamic>{'id': 9301},
        'text': MessageTemplates.buttonSubscribeApply,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9301, 'type': 'private'},
        'from': <String, dynamic>{'id': 9301},
        'text': MessageTemplates.buttonBack,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Твой статус: <b>PRO</b>'));
    });

    test('admin can cancel active subscription by command', () async {
      final sender = _FakeSender();
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..cancelResult = CancelSubscriptionResult(
          outcome: CancelSubscriptionOutcome.success,
          request: SubscriptionRequest(
            id: 4001,
            userId: 9911,
            userUsername: 'pro_user',
            status: SubscriptionRequestStatus.cancelled,
            createdAt: DateTime(2026, 7, 1, 10),
            updatedAt: DateTime(2026, 7, 10, 10),
            activeUntil: DateTime(2026, 7, 10, 10),
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9100},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': '/cancel_subscription 4001',
      });
      final reasonHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonReasonNotConfirmed,
      });
      final commentHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': MessageTemplates.buttonSkipComment,
      });

      expect(handled, isTrue);
      expect(reasonHandled, isTrue);
      expect(commentHandled, isTrue);
      expect(subscriptionRepository.cancelCalls, 1);
      expect(
        sender.messages.any((message) => message.text.contains('Абонемент #4001 отменен')),
        isTrue,
      );
    });

    test('opens profile summary with dedicated my bookings button', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 501,
            userId: 9501,
            title: 'Тренировка: Функциональная',
            startsAt: DateTime(2026, 6, 20, 19, 0),
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..everyFifthProgress = const EveryFifthRewardProgress(
          qualifiedTrainingsCount: 3,
          usedRewardsCount: 0,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()
          ..seedUser(userId: 9501, bonusAvailable: true),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 6, 10, 12, 0),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9501, 'type': 'private'},
        'from': <String, dynamic>{'id': 9501},
        'text': MessageTemplates.buttonProfile,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Профиль DVOR'));
      expect(sender.messages.single.text, contains('Лояльность'));
      expect(sender.messages.single.text, contains(MessageTemplates.buttonProfileBookings));
      expect(sender.messages.single.parseMode, 'HTML');
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonProfileBookings));
      expect(buttons, contains(MessageTemplates.buttonReferralProgram));
    });

    test('opens referral program section from profile', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..referralProgress = const ReferralRewardProgress(
          qualifiedReferralsCount: 2,
          usedRewardsCount: 1,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(botUsername: 'dvor_test_bot'),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9503, 'type': 'private'},
        'from': <String, dynamic>{'id': 9503},
        'text': MessageTemplates.buttonReferralProgram,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('Реферальная программа DVOR'));
      expect(sender.messages.single.text, contains('https://t.me/dvor_test_bot?start=ref_9503'));
      expect(sender.messages.single.text, contains('Доступно бесплатных по рефералке: <b>1</b>'));
      expect(sender.messages.single.parseMode, 'HTML');
    });

    test('shows remaining PRO trainings in profile for active subscription', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          for (var i = 0; i < 3; i++)
            _booking(
              id: 9100 + i,
              userId: 9502,
              status: BookingStatus.paid,
              paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
              updatedAt: DateTime(2026, 7, 12 + i, 10),
            ),
        ];
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.pro
        ..membershipActiveUntil = DateTime(2026, 8, 1, 12);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        subscriptionRepository: subscriptionRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 9502),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9502, 'type': 'private'},
        'from': <String, dynamic>{'id': 9502},
        'text': MessageTemplates.buttonProfile,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('осталось тренировок: <b>5/8</b>'));
    });

    test('handles coaching staff flow with compact list and trainer card', () async {
      final sender = _FakeSender();
      final trainerDirectoryRepository = _FakeTrainerDirectoryRepository(
        const <TrainerInfo>[
          TrainerInfo(
            name: 'Алексей Петров',
            link: '@alxpetrov',
            description: 'Силовая и функциональная подготовка',
            role: 'Силовые и функциональные тренировки',
          ),
          TrainerInfo(
            name: 'Мария Романова',
            link: '@maria_run',
            description: '  Беговые тренировки  \n\n и восстановление  ',
            role: 'Бег и восстановление',
          ),
        ],
      );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        trainerDirectoryRepository: trainerDirectoryRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9102, 'type': 'private'},
        'from': <String, dynamic>{'id': 9102},
        'text': MessageTemplates.buttonCoachingStaff,
      });
      final detailsHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9102, 'type': 'private'},
        'from': <String, dynamic>{'id': 9102},
        'text': MessageTemplates.buttonCoachDetails,
      });
      final profileHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9102, 'type': 'private'},
        'from': <String, dynamic>{'id': 9102},
        'text': '👤 2. Мария Романова',
      });

      expect(handled, isTrue);
      expect(detailsHandled, isTrue);
      expect(profileHandled, isTrue);
      expect(trainerDirectoryRepository.refreshCalls, 1);
      expect(sender.messages, hasLength(3));
      expect(sender.messages.first.text, contains('Тренерский штаб DVOR'));
      expect(sender.messages.first.text, contains('Алексей Петров'));
      expect(sender.messages.first.text, contains('Силовые и функциональные тренировки'));
      expect(sender.messages.first.text, isNot(contains('📝')));
      expect(sender.messages[1].text, contains('Выбери тренера'));
      expect(sender.messages.last.text, contains('<b>Мария Романова</b>'));
      expect(sender.messages.last.text, contains('Направление'));
      expect(sender.messages.last.text, contains('📝 <b>О тренере:</b>'));
      expect(
        sender.messages.last.text,
        contains('\n🔗 <b>Контакт:</b> <a href="https://t.me/maria_run">@maria_run</a>'),
      );
      expect(sender.messages.last.text, contains('Беговые тренировки\n\nи восстановление'));
      expect(sender.messages.first.disableWebPagePreview, isTrue);
      expect(sender.messages.last.disableWebPagePreview, isTrue);
      expect(
        _keyboardTexts(sender.messages.first.replyMarkup),
        contains(MessageTemplates.buttonCoachDetails),
      );
      expect(
        _keyboardTexts(sender.messages[1].replyMarkup),
        contains('👤 1. Алексей Петров'),
      );
      expect(
        _keyboardTexts(sender.messages.last.replyMarkup),
        contains('👤 2. Мария Романова'),
      );
    });

    test('handles wrapped update with message payload', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'update_id': 101,
        'message': <String, dynamic>{
          'chat': <String, dynamic>{'id': 111, 'type': 'private'},
          'from': <String, dynamic>{'id': 111},
          'text': '/start',
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 111);
      expect(sender.messages.single.text, contains('Добро пожаловать в DVOR'));
    });

    test('handles /trainings command with category selection', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тестовая тренировка',
              startsAt: DateTime(2026, 6, 4, 19, 0),
              location: 'Тестовый зал',
              locationUrl: 'https://maps.example/test-gym',
              price: 0,
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'from': <String, dynamic>{'id': 1200},
        'text': '/trainings',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'from': <String, dynamic>{'id': 1200},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Выбери раздел расписания'));
      expect(sender.messages.last.text, contains('Ближайшие тренировки'));
      expect(sender.messages.last.text, contains('Тестовая тренировка'));
      expect(
        sender.messages.last.text,
        contains('<a href="https://maps.example/test-gym">Тестовый зал</a>'),
      );
      expect(sender.messages.last.text, contains('бесплатная'));
      expect(sender.messages.last.text, contains('Выбери мероприятие для записи'));
      expect(sender.messages.last.parseMode, 'HTML');
      expect(sender.messages.last.disableWebPagePreview, isTrue);
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBack));
    });

    test('links coaches in schedule when username is available', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Функциональная тренировка',
              startsAt: DateTime(2026, 6, 6, 19, 0),
              location: 'Зал DVOR',
              coach: 'Алексей Петров, Мария Романова и гость',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        trainerDirectoryRepository: _FakeTrainerDirectoryRepository(
          const <TrainerInfo>[
            TrainerInfo(name: 'Алексей Петров', link: '@alxpetrov', description: 'Head coach'),
            TrainerInfo(
              name: 'Мария Романова',
              link: 'https://t.me/maria_run',
              description: 'Running coach',
            ),
            TrainerInfo(
              name: 'Гость',
              link: 'https://t.me/@guest_coach',
              description: 'Guest coach',
            ),
          ],
        ),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 125, 'type': 'private'},
        'from': <String, dynamic>{'id': 1250},
        'text': '/trainings',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 125, 'type': 'private'},
        'from': <String, dynamic>{'id': 1250},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      final text = sender.messages.last.text;
      expect(
        text,
        contains('<a href="https://t.me/alxpetrov">Алексей Петров</a>'),
      );
      expect(
        text,
        contains('<a href="https://t.me/maria_run">Мария Романова</a>'),
      );
      expect(text, contains('<a href="https://t.me/guest_coach">гость</a>'));
      expect(text, contains('🧑‍🏫 Тренеры:'));
      expect(sender.messages.last.parseMode, 'HTML');
    });

    test('handles menu trainings button in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тренировка из кнопки',
              startsAt: DateTime(2026, 6, 5, 19, 0),
              location: 'Тестовый зал',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 13, 'type': 'private'},
        'from': <String, dynamic>{'id': 1301},
        'text': MessageTemplates.buttonTrainings,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 13, 'type': 'private'},
        'from': <String, dynamic>{'id': 1301},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.last.text, contains('Тренировка из кнопки'));
    });

    test('opens hike selection in schedule category', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тренировка',
              startsAt: DateTime(2026, 6, 5, 19, 0),
              location: 'Зал',
            ),
          ],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на водопады',
              dateFrom: DateTime(2026, 6, 10),
              dateTo: DateTime(2026, 6, 10, 23, 59, 59),
              description: 'Однодневный маршрут',
              price: 2500,
            ),
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл перевал',
              dateFrom: DateTime(2026, 6, 20),
              dateTo: DateTime(2026, 6, 22, 23, 59, 59),
              description: 'Трехдневный трек',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonTrainings,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[1].text, contains('Ближайшие походы OUTDVOR'));
      expect(sender.messages[1].text, contains('50% предоплата при записи'));
      expect(sender.messages[1].text, contains('2500 ₽ (1250 ₽ предоплата 50%)'));
      expect(sender.messages[1].text, contains('Поход на водопады'));
      expect(sender.messages.last.text, contains('Выбери поход из кнопок'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🎯 1. Поход на водопады'));
      expect(buttons, isNot(contains('Трейл перевал')));
    });

    test('opens trail selection in schedule category', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл перевал',
              dateFrom: DateTime(2026, 6, 20),
              dateTo: DateTime(2026, 6, 22, 23, 59, 59),
              description: 'Трехдневный трек',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonCategoryTrails,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[1].text, contains('Ближайшие трейлы OUTDVOR'));
      expect(sender.messages[1].text, contains('50% предоплата при записи'));
      expect(sender.messages[1].text, contains('Трейл перевал'));
      expect(sender.messages.last.text, contains('Выбери трейл из кнопок'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🎯 1. Трейл перевал'));
    });

    test('help button shows client-facing bot capabilities', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 131, 'type': 'private'},
        'from': <String, dynamic>{'id': 1310},
        'text': MessageTemplates.buttonHelp,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(
        sender.messages.single.text,
        contains('Показываю ближайшие тренировки, йогу, походы и трейлы'),
      );
      expect(sender.messages.single.text, contains('каждая 5-я тренировка бесплатная'));
      expect(sender.messages.single.text, contains('Группа DVOR'));
      expect(sender.messages.single.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.single.text, contains('По остальным вопросам: @dvor_support'));
      expect(sender.messages.single.text, isNot(contains('внешнего источника')));
    });

    test('refresh button is forbidden for non-admin users', () async {
      final sender = _FakeSender();
      final repository = _FakeScheduleRepository(const <TrainingInfo>[]);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: repository,
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 14, 'type': 'private'},
        'from': <String, dynamic>{'id': 1302},
        'text': MessageTemplates.buttonRefreshSchedule,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('только для админов'));
      expect(repository.refreshCalls, 0);
    });

    test('refresh button triggers repository sync for admin users', () async {
      final sender = _FakeSender();
      final repository = _FakeScheduleRepository(
        const <TrainingInfo>[],
        refreshResult: true,
      );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: repository,
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1303},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 15, 'type': 'private'},
        'from': <String, dynamic>{'id': 1303},
        'text': MessageTemplates.buttonRefreshSchedule,
      });

      expect(handled, isTrue);
      expect(repository.refreshCalls, 1);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Google Sheets обновлён'));
      expect(sender.messages.last.text, contains(MessageTemplates.scheduleDocumentUrl));
    });

    test('ignores non-private chat messages', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': -1001, 'type': 'supergroup'},
        'text': '/start',
      });

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
    });

    test('sends fallback for unknown private message', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 140, 'type': 'private'},
        'from': <String, dynamic>{'id': 1400},
        'text': 'какая погода?',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Пока не понял сообщение'));
      expect(sender.messages.single.text, contains(MessageTemplates.buttonHelp));
      expect(sender.messages.single.replyMarkup, isNotNull);
    });

    test('ignores pinned service message in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'chat': <String, dynamic>{'id': 141, 'type': 'private'},
          'from': <String, dynamic>{'id': 1410},
          'pinned_message': <String, dynamic>{'message_id': 1},
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, isEmpty);
    });

    test('book command starts booking category selection flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 16, 'type': 'private'},
        'from': <String, dynamic>{'id': 1600},
        'text': '/book',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 0);
      expect(sender.messages.single.text, contains('Выбери категорию для записи'));
    });

    test('book button in selected hike actions creates booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на Бзерпинский карниз',
              dateFrom: DateTime(2026, 7, 20),
              dateTo: DateTime(2026, 7, 21, 23, 59, 59),
              description: 'Двухдневный маршрут',
              price: 4100,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': '🎯 1. Поход на Бзерпинский карниз',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonBookTraining,
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, contains('Поход на Бзерпинский карниз'));
      expect(sender.messages.last.text, contains('записал тебя'));
    });

    test('back from outdoor event selection returns to schedule categories', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл Фишт',
              dateFrom: DateTime(2026, 8, 2),
              dateTo: DateTime(2026, 8, 3, 23, 59, 59),
              description: 'Горный маршрут',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonCategoryTrails,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': '🎯 1. Трейл Фишт',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonBack,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Выбери трейл из кнопок'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🎯 1. Трейл Фишт'));
      expect(buttons, contains(MessageTemplates.buttonBack));
    });

    test('shows outdoor details for selected hike only', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на Бзерпинский карниз',
              dateFrom: DateTime(2026, 7, 20),
              dateTo: DateTime(2026, 7, 21, 23, 59, 59),
              description: 'Двухдневный маршрут',
              equipment: 'Ботинки, дождевик, фонарь',
            ),
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на Ачишхо',
              dateFrom: DateTime(2026, 7, 27),
              dateTo: DateTime(2026, 7, 27, 23, 59, 59),
              description: 'Однодневный маршрут',
              equipment: 'Треккинговые палки',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': MessageTemplates.buttonTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      final opened = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '🎯 1. Поход на Бзерпинский карниз',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '🎯 1. Поход на Бзерпинский карниз',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': MessageTemplates.buttonOutdoorEquipment,
      });

      expect(opened, isTrue);
      final detailsMessage = sender.messages.firstWhere(
        (message) => message.text.contains('Выбери действие'),
      );
      final actionsButtons = _keyboardTexts(detailsMessage.replyMarkup);
      expect(actionsButtons, contains(MessageTemplates.buttonOutdoorEquipment));
      expect(actionsButtons, contains(MessageTemplates.buttonOutdoorItinerary));
      expect(sender.messages[1].text, contains('Ближайшие походы OUTDVOR'));
      expect(detailsMessage.text, contains('Выбери действие'));
      expect(sender.messages.last.text, contains('Экипировка'));
      expect(sender.messages.last.text, contains('Поход на Бзерпинский карниз'));
      expect(sender.messages.last.text, contains('Ботинки, дождевик, фонарь'));
      expect(sender.messages.last.text, isNot(contains('Треккинговые палки')));
    });

    test('creates booking after selecting a training button', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
            TrainingInfo(
              title: 'Second session',
              startsAt: DateTime(2026, 7, 11, 18, 0),
              location: 'Hall 2',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601, 'username': 'second_user'},
        'text': '🎯 2. Second session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, 'Second session');
      expect(bookingRepository.lastCreatedUsername, 'second_user');
      expect(sender.messages.last.text, contains('записал тебя'));
      expect(sender.messages.last.text, contains('Реквизиты для оплаты'));
    });

    test('does not send low-spots group notification for pending payment booking', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Full body',
        startsAt: DateTime(2026, 7, 15, 19, 0),
        location: 'Main hall',
        participantsLimit: 10,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = List<TrainingBooking>.generate(
          8,
          (index) => _booking(
            id: 300 + index,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.pendingPayment,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100777,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': '🎯 1. Full body',
      });

      expect(handled, isTrue);
      final groupMessages = sender.messages.where((message) => message.chatId == -100777).toList();
      expect(groupMessages, isEmpty);
    });

    test('sends low-spots group notification for confirmed booking', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Full body',
        startsAt: DateTime(2026, 7, 15, 19, 0),
        location: 'Main hall',
        participantsLimit: 10,
        price: 0,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = List<TrainingBooking>.generate(
          8,
          (index) => _booking(
            id: 330 + index,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paid,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100777,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1616, 'type': 'private'},
        'from': <String, dynamic>{'id': 1616},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1616, 'type': 'private'},
        'from': <String, dynamic>{'id': 1616},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1616, 'type': 'private'},
        'from': <String, dynamic>{'id': 1616},
        'text': '🎯 1. Full body',
      });

      expect(handled, isTrue);
      final groupMessages = sender.messages.where((message) => message.chatId == -100777).toList();
      expect(groupMessages, hasLength(1));
      expect(groupMessages.single.text, contains('почти не осталось мест'));
      expect(groupMessages.single.text, contains('Свободных мест: 2 из 10'));
    });

    test('deletes previous low-spots message before sending new one', () async {
      final sender = _FakeSender();
      final firstTraining = TrainingInfo(
        title: 'First low spots',
        startsAt: DateTime(2026, 7, 20, 19, 0),
        location: 'Main hall',
        participantsLimit: 10,
        price: 0,
      );
      final secondTraining = TrainingInfo(
        title: 'Second low spots',
        startsAt: DateTime(2026, 7, 21, 19, 0),
        location: 'Main hall',
        participantsLimit: 10,
        price: 0,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          ...List<TrainingBooking>.generate(
            8,
            (index) => _booking(
              id: 600 + index,
              trainingKey: firstTraining.sessionKey,
              title: firstTraining.title,
              startsAt: firstTraining.startsAt,
              location: firstTraining.location,
              status: BookingStatus.paid,
            ),
          ),
          ...List<TrainingBooking>.generate(
            8,
            (index) => _booking(
              id: 700 + index,
              trainingKey: secondTraining.sessionKey,
              title: secondTraining.title,
              startsAt: secondTraining.startsAt,
              location: secondTraining.location,
              status: BookingStatus.paid,
            ),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[firstTraining, secondTraining]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100779,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': '🎯 1. First low spots',
      });

      final groupMessages = sender.messages.where((message) => message.chatId == -100779).toList();
      expect(groupMessages, hasLength(1));
      final firstLowMessageId = sender.messages.indexOf(groupMessages.first) + 1;

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1617, 'type': 'private'},
        'from': <String, dynamic>{'id': 1617},
        'text': '🎯 2. Second low spots',
      });

      expect(handled, isTrue);
      expect(sender.deletedMessages, hasLength(1));
      expect(sender.deletedMessages.single.chatId, -100779);
      expect(sender.deletedMessages.single.messageId, firstLowMessageId);
      final updatedGroupMessages =
          sender.messages.where((message) => message.chatId == -100779).toList();
      expect(updatedGroupMessages, hasLength(2));
    });

    test('sends group notification when no spots are left', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Intense cardio',
        startsAt: DateTime(2026, 7, 16, 20, 0),
        location: 'Arena',
        participantsLimit: 3,
        price: 0,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = List<TrainingBooking>.generate(
          3,
          (index) => _booking(
            id: 500 + index,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paid,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100778,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': '🎯 1. Intense cardio',
      });

      expect(handled, isTrue);
      final groupMessages = sender.messages.where((message) => message.chatId == -100778).toList();
      expect(groupMessages, hasLength(1));
      expect(groupMessages.single.text, contains('Места на эту тренировку закончились'));
      expect(groupMessages.single.text, contains('Участников: 3/3'));
    });

    test('shows error when participants limit is reached during booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..createException = const BookingParticipantsLimitExceededException('limit reached');
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Limited session',
              startsAt: DateTime(2026, 7, 11, 18, 0),
              location: 'Hall 2',
              participantsLimit: 1,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': '🎯 1. Limited session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(sender.messages.last.text, contains('свободных мест больше нет'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🎯 1. Limited session'));
    });

    test('creates free booking without payment confirmation flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 12, 18, 0),
              location: 'Open gym',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -1001612,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '🎯 1. Free session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(sender.messages.last.text, contains('Это бесплатная тренировка'));
      expect(sender.messages.last.text, isNot(contains('Реквизиты для оплаты')));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubmitPayment)));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -1001612).text;
      expect(adminMessage, contains('новая бесплатная запись'));
      expect(adminMessage, contains('Статус: Бесплатно'));
    });

    test('skips payment confirmation flow for whitelisted trainer booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      expect(isTrainerBookingWhitelisted(userId: 857655217, username: '@whatshapped'), isTrue);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 12, 20, 0),
              location: 'Main hall',
              price: 1200,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100111,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 857655217, 'type': 'private'},
        'from': <String, dynamic>{
          'id': 857655217,
          'username': 'whatshapped',
        },
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 857655217, 'type': 'private'},
        'from': <String, dynamic>{
          'id': 857655217,
          'username': 'whatshapped',
        },
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 857655217, 'type': 'private'},
        'from': <String, dynamic>{
          'id': 857655217,
          'username': 'whatshapped',
        },
        'text': '🎯 1. Paid session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastUpdatedBookingId, 99);
      expect(bookingRepository.lastUpdatedStatus, BookingStatus.paid);
      expect(sender.messages.last.text, contains('Ты в списке тренеров'));
      expect(sender.messages.last.text, isNot(contains('Реквизиты для оплаты')));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubmitPayment)));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100111).text;
      expect(adminMessage, contains('тренер записался'));
      expect(adminMessage, contains('tg://user?id=1'));
    });

    test('auto-applies included PRO training when subscription is active', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          for (var i = 1; i <= 7; i++)
            _booking(
              id: 200 + i,
              userId: 1603,
              status: BookingStatus.paid,
              paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
              startsAt: DateTime(2026, 7, 10 + i, 19, 0),
            ),
        ];
      final subscriptionRepository = _FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.pro
        ..membershipActiveUntil = DateTime(2026, 7, 31, 12, 0);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'PRO included session',
              startsAt: DateTime(2026, 7, 25, 19, 0),
              location: 'Main hall',
              price: 1300,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        subscriptionRepository: subscriptionRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 20, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1603, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603, 'username': 'pro_user'},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1603, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603, 'username': 'pro_user'},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1603, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603, 'username': 'pro_user'},
        'text': '🎯 1. PRO included session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.lastUpdatedBookingId, 99);
      expect(bookingRepository.lastUpdatedStatus, BookingStatus.paid);
      expect(
        bookingRepository.lastUpdatedPaymentNote,
        MessageFormatters.proIncludedTrainingPaymentNoteMarker,
      );
      expect(sender.messages.last.text, contains('Включено в PRO'));
      expect(sender.messages.last.text, isNot(contains('Реквизиты для оплаты')));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, isNot(contains(MessageTemplates.buttonSubmitPayment)));
    });

    test('shows starter bonus button and applies free training once', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 1604, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Starter session',
              startsAt: DateTime(2026, 7, 12, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': '🎯 1. Starter session',
      });

      final keyboardBefore = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboardBefore, contains(MessageTemplates.buttonUseStarterBonus));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Бесплатная тренировка активирована'));
      expect(sender.messages.last.text, contains('Статус: Бесплатно: стартовая тренировка 🎁'));
    });

    test('sends admin notification for starter bonus booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 1605, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Admin starter session',
              startsAt: DateTime(2026, 7, 13, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100778,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': '🎯 1. Admin starter session',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100778).text;
      expect(adminMessage, contains('Стартовая бесплатная запись'));
      expect(adminMessage, contains('Формат: бесплатная тренировка за старт'));
    });

    test('applies every-fifth bonus when starter bonus unavailable', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..everyFifthProgress = const EveryFifthRewardProgress(
          qualifiedTrainingsCount: 8,
          usedRewardsCount: 1,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Fifth reward session',
              startsAt: DateTime(2026, 7, 14, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 1606),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100889,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': '🎯 1. Fifth reward session',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('каждая 5-я бесплатно'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100889).text;
      expect(adminMessage, contains('каждая 5-я'));
    });

    test('applies referral bonus when referral reward is available', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..referralProgress = const ReferralRewardProgress(
          qualifiedReferralsCount: 2,
          usedRewardsCount: 1,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Referral reward session',
              startsAt: DateTime(2026, 7, 15, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 1608),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100445,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608, 'username': 'ref_user'},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608, 'username': 'ref_user'},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608, 'username': 'ref_user'},
        'text': '🎯 1. Referral reward session',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608, 'username': 'ref_user'},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Реферальная бесплатная тренировка активирована'));
      expect(bookingRepository.lastUpdatedPaymentNote,
          MessageFormatters.referralBonusPaymentNoteMarker);
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100445).text;
      expect(adminMessage, contains('реферальной программе'));
    });

    test('notifies user and admin when every-fifth reward unlocks', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..everyFifthProgress = const EveryFifthRewardProgress(
          qualifiedTrainingsCount: 4,
          usedRewardsCount: 0,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 1607),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100999,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 167, 'type': 'private'},
        'from': <String, dynamic>{'id': 1607, 'username': 'unlock_user'},
        'text': '/my_bookings',
      });

      expect(handled, isTrue);
      final userNotify = sender.messages.firstWhere((message) => message.chatId == 167).text;
      final adminNotify = sender.messages.firstWhere((message) => message.chatId == -100999).text;
      expect(userNotify, contains('Новая бесплатная тренировка'));
      expect(adminNotify, contains('@unlock_user'));
    });

    test('creates booking after selecting a hike category item', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на хребет',
              dateFrom: DateTime(2026, 7, 13),
              dateTo: DateTime(2026, 7, 14, 23, 59, 59),
              location: 'Лаго-Наки, старт от кордона',
              description: 'Ночевка в лагере',
              price: 3200,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      final chooseActivityText = sender.messages.last.text;
      expect(chooseActivityText, contains('Выбери мероприятие для записи'));
      expect(chooseActivityText, contains('🥾 Поход: Поход на хребет'));
      expect(chooseActivityText, contains('🕒 13.07.2026'));
      expect(chooseActivityText, isNot(contains('13.07.2026 00:00')));
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': '🎯 1. 🥾 Поход: Поход на хребет',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, contains('Поход на хребет'));
      expect(
          bookingRepository.lastCreatedTraining?.location, contains('Лаго-Наки, старт от кордона'));
      final ruleIndex =
          sender.messages.indexWhere((message) => message.text.contains('Правило OUTDVOR'));
      final requisitesIndex =
          sender.messages.indexWhere((message) => message.text.contains('Реквизиты OUTDVOR'));
      expect(ruleIndex, greaterThanOrEqualTo(0));
      expect(requisitesIndex, greaterThan(ruleIndex));
      expect(sender.messages.last.text, contains('записал тебя'));
      expect(sender.messages.last.text, contains('Событие: 🥾 Поход: Поход на хребет'));
      expect(sender.messages.last.text, isNot(contains('Тренировка:')));
      expect(sender.messages.last.text, contains('📍 Где: Лаго-Наки, старт от кордона'));
    });

    test('payment is not submitted without proof file', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': '🎯 1. Book me',
      });

      final submitted = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': MessageTemplates.buttonSubmitPayment,
      });
      expect(submitted, isTrue);
      expect(bookingRepository.submitCalls, 0);
      expect(sender.messages.last.text, contains('Пришли файл'));
    });

    test('asks for payment proof file when text is sent at confirmation step', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': '🎯 1. Book me',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': 'уже оплатил',
      });

      expect(handled, isTrue);
      expect(bookingRepository.submitCalls, 0);
      expect(sender.messages.last.text, contains('Пришли файл'));
    });

    test('cancels outdoor pending booking from payment confirmation step', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 99,
            userId: 1608,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Архыз',
              dateFrom: now.add(const Duration(days: 9)),
              dateTo: now.add(const Duration(days: 9, hours: 8)),
              description: 'Маршрут',
              price: 4500,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': '🎯 1. 🥾 Поход: Архыз',
      });

      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonCancelBooking));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 99);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('cancels latest pending outdoor booking without active flow', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 450,
            userId: 2601,
            trainingKey: 'trails|2026-06-12T09:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 11)),
            location: 'Горы',
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 450,
            userId: 2601,
            trainingKey: 'trails|2026-06-12T09:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 11)),
            location: 'Горы',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 269, 'type': 'private'},
        'from': <String, dynamic>{'id': 2601},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 269, 'type': 'private'},
        'from': <String, dynamic>{'id': 2601},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 450);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('submits payment after sending payment proof file', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': '🎯 1. Book me',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'message_id': 301,
          'chat': <String, dynamic>{'id': 17, 'type': 'private'},
          'from': <String, dynamic>{'id': 1700},
          'document': <String, Object?>{'file_id': 'doc-proof'},
          'caption': 'Оплата по booking 99',
        },
      });

      expect(handled, isTrue);
      expect(bookingRepository.submitCalls, 1);
      expect(bookingRepository.lastSubmittedBookingId, 99);
      expect(sender.messages.last.text,
          contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('sends admin chat notification only after proof file is sent', () async {
      final sender = _FakeSender();
      final submittedBooking = _booking(
        id: 55,
        userId: 1701,
        title: 'Functional',
        status: BookingStatus.paymentSubmitted,
      );
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = submittedBooking
        ..queue = <TrainingBooking>[submittedBooking];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Functional',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100777,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': '🎯 1. Functional',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'message_id': 401,
          'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
          'from': <String, dynamic>{'id': 1701},
          'photo': <Map<String, Object?>>[
            <String, Object?>{'file_id': 'photo-proof'},
          ],
        },
      });

      expect(handled, isTrue);
      expect(sender.copiedMessages, isEmpty);
      final adminNotification = sender.messages[sender.messages.length - 2];
      expect(adminNotification.chatId, -100777);
      expect(adminNotification.text, contains('Новое подтверждение оплаты'));
      expect(adminNotification.text, contains('Мероприятие: Functional'));
      final adminMarkup = adminNotification.replyMarkup;
      expect(adminMarkup, isNotNull);
      expect(adminMarkup!['inline_keyboard'], isA<List<Object?>>());
      final adminKeyboard = adminMarkup['inline_keyboard']! as List<Object?>;
      final adminFirstRow = adminKeyboard.first as List<Object?>;
      final openQueueButton = adminFirstRow.first as Map<Object?, Object?>;
      expect(openQueueButton['text'], '${MessageTemplates.buttonPaymentsQueue} (1)');
      expect(openQueueButton['callback_data'], MessageTemplates.callbackOpenPaymentsQueue);
      final userConfirmation = sender.messages.last;
      expect(userConfirmation.chatId, 1701);
      expect(
          userConfirmation.text, contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('shows payments queue for selected admin category', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(
            id: 81,
            status: BookingStatus.paymentSubmitted,
            paymentProofChatId: 50081,
            paymentProofMessageId: 90081,
          ),
          _booking(
            id: 82,
            status: BookingStatus.paymentSubmitted,
            title: '🥾 Поход: Morning session',
            userUsername: 'queue_user',
            paymentProofChatId: 50082,
            paymentProofMessageId: 90082,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1800},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 18, 'type': 'private'},
        'from': <String, dynamic>{'id': 1800},
        'text': '/payments_queue',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 18, 'type': 'private'},
        'from': <String, dynamic>{'id': 1800},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages.first.text, contains('Очередь заявок на оплату'));
      final categoryMarkup = sender.messages.first.replyMarkup;
      expect(categoryMarkup, isNotNull);
      expect(
        categoryMarkup!['keyboard'],
        <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': '${MessageTemplates.buttonCategoryTrainings} (1)'},
            <String, String>{'text': '${MessageTemplates.buttonCategoryYoga} (0)'},
          ],
          <Map<String, String>>[
            <String, String>{'text': '${MessageTemplates.buttonCategoryHikes} (1)'},
            <String, String>{'text': '${MessageTemplates.buttonCategoryTrails} (0)'},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageTemplates.buttonBack},
            <String, String>{'text': MessageTemplates.buttonMainMenu},
          ],
        ],
      );
      expect(sender.messages[1].text, contains('Всего ожидают проверки: <b>1</b>'));
      expect(sender.copiedMessages, hasLength(1));
      expect(sender.copiedMessages.single.toChatId, 18);
      expect(sender.copiedMessages.single.fromChatId, 50082);
      expect(sender.copiedMessages.single.messageId, 90082);

      final firstItemMessage = sender.messages[2];
      expect(firstItemMessage.text, contains('Заявка #82'));
      final markup = firstItemMessage.replyMarkup;
      expect(markup, isNotNull);
      final keyboard = markup!['inline_keyboard'];
      expect(keyboard, isA<List<Object?>>());

      final firstRow = (keyboard as List<Object?>).first as List<Object?>;
      final approveButton = firstRow.first as Map<Object?, Object?>;
      expect(approveButton['text'], '✅ Подтвердить оплату');
    });

    test('splits my bookings into upcoming and past sections', () {
      final templates = const MessageTemplates();
      final text = templates.myBookings(
        <TrainingBooking>[
          _booking(
            id: 90,
            startsAt: DateTime(2026, 6, 20, 19, 0),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 91,
            startsAt: DateTime(2026, 5, 20, 19, 0),
            status: BookingStatus.paid,
          ),
        ],
        now: DateTime(2026, 6, 1, 12, 0),
      );

      expect(text, contains('Актуальные'));
      expect(text, contains('Прошедшие'));
      expect(text, contains('#90'));
      expect(text, contains('#91'));
    });

    test('shows date without time for hike and trail bookings', () {
      final templates = const MessageTemplates();
      final text = templates.myBookings(
        <TrainingBooking>[
          _booking(
            id: 92,
            title: '🏃 Трейл: TRAIL двора — Адыгея',
            startsAt: DateTime(2026, 6, 6, 0, 0),
            status: BookingStatus.paid,
          ),
          _booking(
            id: 93,
            title: '🥾 Поход: Лаго-Наки',
            startsAt: DateTime(2026, 6, 7, 14, 30),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 94,
            title: 'Тренировка: Функциональная',
            startsAt: DateTime(2026, 6, 8, 19, 15),
            status: BookingStatus.pendingPayment,
          ),
        ],
        now: DateTime(2026, 6, 1, 12, 0),
      );

      expect(text, contains('🏃 Трейл: TRAIL двора — Адыгея</b>\n🕒 06.06.2026\n'));
      expect(text, contains('🥾 Поход: Лаго-Наки</b>\n🕒 07.06.2026\n'));
      expect(text, contains('Тренировка: Функциональная</b>\n🕒 08.06.2026 19:15\n'));
      expect(text, isNot(contains('06.06.2026 00:00')));
      expect(text, isNot(contains('07.06.2026 14:30')));
    });

    test('uses date without time in outdoor booking confirmations', () {
      final templates = const MessageTemplates();
      final outdoorBooking = _booking(
        id: 95,
        trainingKey: 'hikes|2026-06-07T00:00:00.000Z|🥾 Поход: ЧЕРНОГОР|Маршрут',
        title: '🥾 Поход: ЧЕРНОГОР ВОСХОЖДЕНИЕ',
        startsAt: DateTime(2026, 6, 7, 14, 30),
      );

      final createdText = templates.bookingCreated(outdoorBooking);
      final existingText = templates.bookingAlreadyExists(outdoorBooking);
      final reminderText = templates.pendingPaymentReminder(outdoorBooking);

      expect(createdText, contains('🕒 Когда: 07.06.2026'));
      expect(existingText, contains('🕒 Когда: 07.06.2026'));
      expect(reminderText, contains('ЧЕРНОГОР ВОСХОЖДЕНИЕ (07.06.2026)'));

      expect(createdText, isNot(contains('07.06.2026 14:30')));
      expect(existingText, isNot(contains('07.06.2026 14:30')));
      expect(reminderText, isNot(contains('07.06.2026 14:30')));
    });

    test('uses dedicated payment details and contacts for yoga booking', () {
      final templates = const MessageTemplates();
      final yogaBooking = _booking(
        id: 196,
        trainingKey: 'yoga|2026-07-12T17:00:00.000Z|Йога баланс|Студия',
        title: 'Йога баланс',
        startsAt: DateTime(2026, 7, 12, 17, 0),
      );

      final detailsText = templates.paymentDetailsSent(yogaBooking);

      expect(detailsText, contains('Елена П.'));
      expect(detailsText, contains('Т-БАНК'));
      expect(detailsText, contains('+7(961)313-11-44'));
      expect(detailsText, contains('По вопросам теории и практики'));
      expect(detailsText, contains('@dvor_support'));
    });

    test('reschedules training booking from my bookings and notifies admin chat', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 301,
            userId: 2301,
            trainingKey: TrainingInfo(
              title: 'Old session',
              startsAt: DateTime(2026, 7, 5, 19, 0),
              location: 'Hall A',
            ).sessionKey,
            title: 'Old session',
            startsAt: DateTime(2026, 7, 5, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
          ),
        ]
        ..rescheduleResult = BookingRescheduleResult(
          outcome: BookingRescheduleOutcome.success,
          booking: _booking(
            id: 301,
            userId: 2301,
            trainingKey: TrainingInfo(
              title: 'New session',
              startsAt: DateTime(2026, 7, 8, 19, 0),
              location: 'Hall B',
            ).sessionKey,
            title: 'New session',
            startsAt: DateTime(2026, 7, 8, 19, 0),
            location: 'Hall B',
            status: BookingStatus.paid,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Old session',
              startsAt: DateTime(2026, 7, 5, 19, 0),
              location: 'Hall A',
            ),
            TrainingInfo(
              title: 'New session',
              startsAt: DateTime(2026, 7, 8, 19, 0),
              location: 'Hall B',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100601,
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonCurrentBookings,
      });
      final afterSelection = sender.messages.last;
      expect(_keyboardTexts(afterSelection.replyMarkup), contains('🧾 #301 Old session'));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🧾 #301 Old session',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonRescheduleBooking));
      expect(actionButtons, isNot(contains(MessageTemplates.buttonCancelBooking)));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🎯 2. New session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 1);
      expect(bookingRepository.lastRescheduledBookingId, 301);
      expect(bookingRepository.lastRescheduleTraining?.title, 'New session');
      expect(sender.messages.last.chatId, 2301);
      expect(sender.messages.last.text, contains('перенесена'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100601);
      expect(adminMessage.text, contains('Операционное событие: перенос записи'));
      expect(adminMessage.text, contains('Было: Old session'));
      expect(adminMessage.text, contains('Стало: New session'));
    });

    test('does not allow rescheduling free booking to paid training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 351,
            userId: 2351,
            trainingKey: TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 0,
            ).sessionKey,
            title: 'Free session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.freeTraining,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 0,
            ),
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 2500,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '🧾 #351 Free session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '🎯 2. Paid session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на платную тренировку'));
    });

    test('does not allow rescheduling paid booking to free training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 353,
            userId: 2353,
            trainingKey: TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ).sessionKey,
            title: 'Paid session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
            trainingPrice: 2500,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ),
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '🧾 #353 Paid session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '🎯 2. Free session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на бесплатную тренировку'));
    });

    test('does not allow rescheduling paid booking to training with different price', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 354,
            userId: 2354,
            trainingKey: TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ).sessionKey,
            title: 'Paid session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
            trainingPrice: 2500,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ),
            TrainingInfo(
              title: 'Premium session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 3000,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '🧾 #354 Paid session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '🎯 2. Premium session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('с другой стоимостью'));
    });

    test('does not allow rescheduling zero-price booking to paid training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 352,
            userId: 2352,
            trainingKey: TrainingInfo(
              title: 'Community class',
              startsAt: DateTime(2026, 7, 7, 20, 0),
              location: 'Hall C',
              price: 0,
            ).sessionKey,
            title: 'Community class',
            startsAt: DateTime(2026, 7, 7, 20, 0),
            location: 'Hall C',
            status: BookingStatus.paid,
            trainingPrice: 0,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Community class',
              startsAt: DateTime(2026, 7, 7, 20, 0),
              location: 'Hall C',
              price: 0,
            ),
            TrainingInfo(
              title: 'Premium class',
              startsAt: DateTime(2026, 7, 12, 20, 0),
              location: 'Hall D',
              price: 2800,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '🧾 #352 Community class',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '🎯 2. Premium class',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на платную тренировку'));
    });

    test('shows conflict message when rescheduling to already booked training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 302,
            userId: 2302,
            trainingKey: TrainingInfo(
              title: 'Core',
              startsAt: DateTime(2026, 7, 6, 19, 0),
              location: 'Hall A',
            ).sessionKey,
            title: 'Core',
            startsAt: DateTime(2026, 7, 6, 19, 0),
            location: 'Hall A',
          ),
        ]
        ..rescheduleResult = const BookingRescheduleResult(
          outcome: BookingRescheduleOutcome.conflict,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Core',
              startsAt: DateTime(2026, 7, 6, 19, 0),
              location: 'Hall A',
            ),
            TrainingInfo(
              title: 'Speed',
              startsAt: DateTime(2026, 7, 9, 19, 0),
              location: 'Hall B',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => DateTime(2026, 7, 1, 12),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🧾 #302 Core',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🎯 2. Speed',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 1);
      expect(sender.messages.last.text, contains('уже есть запись на выбранную тренировку'));
    });

    test('keeps active booking manageable when history has many archived items', () async {
      final sender = _FakeSender();
      final now = DateTime.now();
      final archived = List<TrainingBooking>.generate(
        12,
        (index) => _booking(
          id: 3600 + index,
          userId: 2360,
          trainingKey: 'hikes|archived-$index',
          title: 'Архивный поход #$index',
          startsAt: now.subtract(Duration(days: 40 + index)),
          location: 'Archive',
          status: BookingStatus.cancelled,
        ),
      );
      final active = _booking(
        id: 3699,
        userId: 2360,
        trainingKey: 'hikes|active-slot',
        title: '🥾 Поход: Живой слот',
        startsAt: now.add(const Duration(days: 10)),
        location: 'Маршрут',
        status: BookingStatus.paid,
      );
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[...archived, active];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2360, 'type': 'private'},
        'from': <String, dynamic>{'id': 2360},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2360, 'type': 'private'},
        'from': <String, dynamic>{'id': 2360},
        'text': MessageTemplates.buttonCurrentBookings,
      });

      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🧾 #3699 🥾 Поход: Живой слот'));
      expect(buttons, isNot(contains('🧾 #3600 Архивный поход #0')));
    });

    test('cancels outdoor booking before 7 days and notifies admin chat', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 401,
            userId: 2401,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.paid,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 401,
            userId: 2401,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100602,
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': '🧾 #401 🥾 Поход: Архыз',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonCancelBooking));
      expect(actionButtons, isNot(contains(MessageTemplates.buttonRescheduleBooking)));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 401);
      expect(sender.messages.last.text, contains('отменена'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100602);
      expect(adminMessage.text, contains('Операционное событие: отмена записи'));
      expect(adminMessage.text, contains('🥾 Поход: Архыз'));
    });

    test('does not notify admin chat on cancellation before payment', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 411,
            userId: 2411,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Домбай|Маршрут',
            title: '🥾 Поход: Домбай',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 411,
            userId: 2411,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Домбай|Маршрут',
            title: '🥾 Поход: Домбай',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100603,
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2411, 'type': 'private'},
        'from': <String, dynamic>{'id': 2411},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2411, 'type': 'private'},
        'from': <String, dynamic>{'id': 2411},
        'text': '🧾 #411 🥾 Поход: Домбай',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2411, 'type': 'private'},
        'from': <String, dynamic>{'id': 2411},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2411, 'type': 'private'},
        'from': <String, dynamic>{'id': 2411},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 411);
      expect(sender.messages.last.text, contains('отменена'));
      final adminMessages = sender.messages.where((message) => message.chatId == -100603).toList();
      expect(adminMessages, isEmpty);
    });

    test('does not cancel outdoor booking when less than 7 days left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 402,
            userId: 2402,
            trainingKey: 'trails|2026-06-08T11:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 6, hours: 23)),
            location: 'Горы',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': '🧾 #402 🏃 Трейл: Плато',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 0);
      expect(sender.messages.last.text, contains('меньше 7 дней'));
    });

    test('cancels yoga booking when at least 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 403,
            userId: 2403,
            trainingKey: 'yoga|2026-06-03T12:30:00.000Z|Утренняя йога|Студия',
            title: 'Утренняя йога',
            startsAt: now.add(const Duration(days: 2)),
            location: 'Студия',
            status: BookingStatus.paid,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 403,
            userId: 2403,
            trainingKey: 'yoga|2026-06-03T12:30:00.000Z|Утренняя йога|Студия',
            title: 'Утренняя йога',
            startsAt: now.add(const Duration(days: 2)),
            location: 'Студия',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': '🧾 #403 Утренняя йога',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 403);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('does not cancel yoga booking when less than 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 404,
            userId: 2404,
            trainingKey: 'yoga|2026-06-02T10:30:00.000Z|Вечерняя йога|Студия',
            title: 'Вечерняя йога',
            startsAt: now.add(const Duration(hours: 23)),
            location: 'Студия',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': '🧾 #404 Вечерняя йога',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 0);
      expect(sender.messages.last.text, contains('меньше 24 часов'));
      expect(sender.messages.last.text, contains('@dvor_support'));
    });

    test('cancels free training even when less than 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 405,
            userId: 2405,
            trainingKey: 'trainings|2026-06-02T10:30:00.000Z|Free session|Hall A',
            title: 'Free session',
            startsAt: now.add(const Duration(hours: 2)),
            location: 'Hall A',
            status: BookingStatus.freeTraining,
            trainingPrice: 0,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: fakeBooking(
            id: 405,
            userId: 2405,
            trainingKey: 'trainings|2026-06-02T10:30:00.000Z|Free session|Hall A',
            title: 'Free session',
            startsAt: now.add(const Duration(hours: 2)),
            location: 'Hall A',
            status: BookingStatus.cancelled,
            trainingPrice: 0,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2405, 'type': 'private'},
        'from': <String, dynamic>{'id': 2405},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2405, 'type': 'private'},
        'from': <String, dynamic>{'id': 2405},
        'text': '🧾 #405 Free session',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonCancelBooking));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2405, 'type': 'private'},
        'from': <String, dynamic>{'id': 2405},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2405, 'type': 'private'},
        'from': <String, dynamic>{'id': 2405},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 405);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('cancels bonus free training even when less than 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 406,
            userId: 2406,
            trainingKey: 'trainings|2026-06-02T10:30:00.000Z|Bonus session|Hall B',
            title: 'Bonus session',
            startsAt: now.add(const Duration(hours: 3)),
            location: 'Hall B',
            status: BookingStatus.paid,
            trainingPrice: 2500,
            paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: fakeBooking(
            id: 406,
            userId: 2406,
            trainingKey: 'trainings|2026-06-02T10:30:00.000Z|Bonus session|Hall B',
            title: 'Bonus session',
            startsAt: now.add(const Duration(hours: 3)),
            location: 'Hall B',
            status: BookingStatus.cancelled,
            trainingPrice: 2500,
            paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2406, 'type': 'private'},
        'from': <String, dynamic>{'id': 2406},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2406, 'type': 'private'},
        'from': <String, dynamic>{'id': 2406},
        'text': '🧾 #406 Bonus session',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonCancelBooking));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2406, 'type': 'private'},
        'from': <String, dynamic>{'id': 2406},
        'text': MessageTemplates.buttonCancelBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2406, 'type': 'private'},
        'from': <String, dynamic>{'id': 2406},
        'text': MessageTemplates.buttonConfirmCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 406);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('shows participants list for selected admin category', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Morning Run',
        startsAt: DateTime(2026, 9, 2, 7, 30),
        location: 'Park',
      );
      final archivedTraining = TrainingInfo(
        title: 'Old Run',
        startsAt: DateTime(2025, 9, 2, 7, 30),
        location: 'Old Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 70,
            userId: 7001,
            userUsername: 'runner_one',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
          ),
          _booking(
            id: 72,
            userId: 857655217,
            userUsername: 'nudden',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
          ),
          _booking(
            id: 73,
            userId: 7003,
            userUsername: 'runner_rejected',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paymentRejected,
          ),
          _booking(
            id: 74,
            userId: 7004,
            userUsername: 'runner_cancelled',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.cancelled,
          ),
          _booking(
            id: 75,
            userId: 7005,
            userUsername: 'runner_archived',
            trainingKey: archivedTraining.sessionKey,
            title: archivedTraining.title,
            startsAt: archivedTraining.startsAt,
            location: archivedTraining.location,
            status: BookingStatus.paid,
          ),
        ];
      bookingRepository.adminBookings = <TrainingBooking>[
        _booking(
          id: 75,
          userId: 7005,
          userUsername: 'runner_archived',
          trainingKey: archivedTraining.sessionKey,
          title: archivedTraining.title,
          startsAt: archivedTraining.startsAt,
          location: archivedTraining.location,
          status: BookingStatus.paid,
        ),
      ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2000},
        nowProvider: () => DateTime(2026, 8, 1, 12, 0),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2000},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2000},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Список записавшихся'));
      expect(sender.messages.last.text, contains('Список записавшихся'));
      expect(sender.messages.last.text, contains('👥 Участники: 1/∞'));
      expect(sender.messages.last.text, contains('👤 Участники:'));
      expect(sender.messages.last.text, contains('@runner_one'));
      expect(sender.messages.last.text, contains('🧑‍🏫 Тренеры:'));
      expect(
        sender.messages.last.text,
        contains('@nudden (Бесплатно: стартовая тренировка 🎁)'),
      );
      expect(sender.messages.last.text, contains('@runner_cancelled (Отменено ❌)'));
      expect(
        sender.messages.last.text.indexOf('@runner_cancelled'),
        greaterThan(sender.messages.last.text.indexOf('@nudden')),
      );
      expect(sender.messages.last.text, isNot(contains('Old Run')));
      expect(sender.messages.last.text, isNot(contains('@runner_archived (Оплачено ✅)')));
      expect(sender.messages.last.text, isNot(contains('@runner_rejected')));
    });

    test('shows yoga participants list directly for yoga trainer role', () async {
      final sender = _FakeSender();
      final yoga = TrainingInfo(
        title: 'Sunrise Yoga',
        startsAt: DateTime(2026, 9, 3, 8, 0),
        location: 'Yoga Hall',
        category: ActivityCategory.yoga,
      );
      final run = TrainingInfo(
        title: 'Morning Run',
        startsAt: DateTime(2026, 9, 3, 7, 0),
        location: 'Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 801,
            userId: 8101,
            userUsername: 'yogi',
            trainingKey: yoga.sessionKey,
            title: yoga.title,
            startsAt: yoga.startsAt,
            location: yoga.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 802,
            userId: 8102,
            userUsername: 'runner',
            trainingKey: run.sessionKey,
            title: run.title,
            startsAt: run.startsAt,
            location: run.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[yoga, run]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 857655217, 'type': 'private'},
        'from': <String, dynamic>{'id': 857655217},
        'text': MessageTemplates.buttonParticipantsList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Список записавшихся'));
      expect(sender.messages.single.text, contains('@yogi'));
      expect(sender.messages.single.text, isNot(contains('@runner')));
      expect(sender.messages.single.text, isNot(contains('Выбери категорию')));
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
    });

    test('merges outdoor participants when activity date changes', () async {
      final sender = _FakeSender();
      final oldHike = TrainingInfo(
        title: '🥾 Поход: DVORCAMP',
        startsAt: DateTime(2030, 7, 2),
        location: 'Старое описание похода',
        category: ActivityCategory.hikes,
      );
      final newHike = TrainingInfo(
        title: '🥾 Поход: DVORCAMP',
        startsAt: DateTime(2030, 7, 3),
        location: 'Новое описание похода',
        category: ActivityCategory.hikes,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 902,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: newHike.sessionKey,
            title: newHike.title,
            startsAt: newHike.startsAt,
            location: newHike.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 903,
            userId: 9002,
            userUsername: 'hike_cancelled',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'DVORCAMP',
              dateFrom: newHike.startsAt,
              dateTo: newHike.startsAt,
              description: newHike.location,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2001},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('🥾 Поход: DVORCAMP').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 03.07.2030'));
      expect(messageText, isNot(contains('🕒 02.07.2030')));
      expect(RegExp('@mi_harkevich').allMatches(messageText).length, 1);
      expect(messageText, isNot(contains('@hike_cancelled (Отменено ❌)')));
    });

    test('merges trail participants when activity date changes', () async {
      final sender = _FakeSender();
      final oldTrail = TrainingInfo(
        title: '🏃 Трейл: Лаго-Наки',
        startsAt: DateTime(2026, 8, 10),
        location: 'Описание версии 1',
        category: ActivityCategory.trails,
      );
      final newTrail = TrainingInfo(
        title: '🏃 Трейл: Лаго-Наки',
        startsAt: DateTime(2026, 8, 12),
        location: 'Описание версии 2',
        category: ActivityCategory.trails,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 910,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 911,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: newTrail.sessionKey,
            title: newTrail.title,
            startsAt: newTrail.startsAt,
            location: newTrail.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 912,
            userId: 9102,
            userUsername: 'trail_cancelled',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 910,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Лаго-Наки',
              dateFrom: newTrail.startsAt,
              dateTo: newTrail.startsAt,
              description: newTrail.location,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2002},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2002},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2002},
        'text': MessageTemplates.buttonCategoryTrails,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('🏃 Трейл: Лаго-Наки').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 12.08.2026'));
      expect(messageText, isNot(contains('🕒 10.08.2026')));
      expect(RegExp('@trail_runner').allMatches(messageText).length, 1);
      expect(messageText, isNot(contains('@trail_cancelled (Отменено ❌)')));
    });

    test('displays trainers in hikes participants list', () async {
      final sender = _FakeSender();
      final hike = TrainingInfo(
        title: '🥾 Поход: Эльбрус',
        startsAt: DateTime(2026, 9, 12),
        location: 'Горный лагерь',
        category: ActivityCategory.hikes,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 930,
            userId: 9301,
            userUsername: 'hike_user',
            trainingKey: hike.sessionKey,
            title: hike.title,
            startsAt: hike.startsAt,
            location: hike.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 931,
            userId: 999001,
            userUsername: '@whatshapped',
            trainingKey: hike.sessionKey,
            title: hike.title,
            startsAt: hike.startsAt,
            location: hike.location,
            status: BookingStatus.paid,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 930,
            userId: 9301,
            userUsername: 'hike_user',
            trainingKey: hike.sessionKey,
            title: hike.title,
            startsAt: hike.startsAt,
            location: hike.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Эльбрус',
              dateFrom: hike.startsAt,
              dateTo: hike.startsAt,
              description: hike.location,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2003},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(messageText, contains('@hike_user'));
      expect(messageText, contains('🧑‍🏫 Тренеры:'));
      expect(messageText, contains('@whatshapped'));
    });

    test('merges training participants when session date changes', () async {
      final sender = _FakeSender();
      final oldTraining = TrainingInfo(
        title: 'Функционалка',
        startsAt: DateTime(2026, 9, 1, 19, 0),
        location: 'Зал А',
      );
      final newTraining = TrainingInfo(
        title: 'Функционалка',
        startsAt: DateTime(2026, 9, 2, 19, 0),
        location: 'Зал А',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 920,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 921,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: newTraining.sessionKey,
            title: newTraining.title,
            startsAt: newTraining.startsAt,
            location: newTraining.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 922,
            userId: 9202,
            userUsername: 'fit_cancelled',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 920,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[newTraining]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2003},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('Функционалка').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 02.09.2026 19:00'));
      expect(messageText, isNot(contains('🕒 01.09.2026 19:00')));
      expect(RegExp('@fit_user').allMatches(messageText).length, 1);
      expect(messageText, isNot(contains('@fit_cancelled (Отменено ❌)')));
    });

    test('shows nobles list for admin with training counts', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(
            id: 801,
            userId: 5002,
            userUsername: 'runner_two',
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 802,
            userId: 5001,
            userUsername: 'runner_one',
            status: BookingStatus.paid,
          ),
          _booking(
            id: 803,
            userId: 5001,
            userUsername: 'runner_one',
            status: BookingStatus.paymentSubmitted,
          ),
          _booking(
            id: 804,
            userId: 5003,
            status: BookingStatus.paymentRejected,
          ),
          _booking(
            id: 805,
            userId: 5001,
            userUsername: 'runner_one',
            title: '🥾 Поход: Архыз',
            status: BookingStatus.paid,
          ),
          _booking(
            id: 806,
            userId: 5002,
            userUsername: 'runner_two',
            title: '🏃 Трейл: Лаго-Наки',
            status: BookingStatus.paymentSubmitted,
          ),
          _booking(
            id: 807,
            userId: 5004,
            userUsername: 'future_runner',
            title: 'Future training',
            status: BookingStatus.paid,
            startsAt: DateTime(2026, 10, 1, 19, 0),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2100},
        nowProvider: () => DateTime(2026, 9, 1, 0, 0),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2100},
        'text': MessageTemplates.buttonNoblesList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      final text = sender.messages.single.text;
      expect(text, contains('Список дворян'));
      expect(text, contains('Всего записей на тренировки:'));
      expect(text, contains('В зачет идут только уже прошедшие по времени тренировки'));
      expect(text, contains('1. @runner_one (5001) —'));
      expect(text, contains('2. @runner_two (5002) —'));
      expect(text, contains('tg://user?id=5003 (5003) —'));
      expect(text, isNot(contains('@future_runner')));
      expect(text, isNot(contains('Поход')));
      expect(text, isNot(contains('Трейл')));
    });

    test('forbids nobles list for non-admin users', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9999},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 22, 'type': 'private'},
        'from': <String, dynamic>{'id': 2200},
        'text': MessageTemplates.buttonNoblesList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('только администраторам'));
    });

    test('shows tg user link when participant has no username', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Evening Run',
        startsAt: DateTime(2026, 9, 3, 19, 30),
        location: 'Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 71,
            userId: 7101,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2001},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.last.text, contains('tg://user?id=7101'));
    });

    test('opens admin booking management menu', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2300},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2300},
        'text': MessageTemplates.buttonManageBookings,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Управление записями'));
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookingsList));
      expect(buttons, contains(MessageTemplates.buttonCreateBooking));
    });

    test('paginates admin bookings list in management flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 9, archived: 0)
        ..adminBookings = List<TrainingBooking>.generate(
          9,
          (index) => _booking(
            id: 601 + index,
            userId: 9601 + index,
            title: 'Morning Run ${index + 1}',
            startsAt: DateTime(2026, 10, 1 + index, 10, 0),
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2305},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': '${MessageTemplates.buttonActiveBookings} (9)',
      });
      final firstPageHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(firstPageHandled, isTrue);
      expect(sender.messages.last.text, contains('Страница <b>1/2</b>'));
      expect(sender.messages.last.text, contains('Записи на текущей странице'));
      expect(sender.messages.last.text, contains('1. #601 Morning Run 1'));
      expect(sender.messages.last.text, contains('8. #608 Morning Run 8'));
      expect(sender.messages.last.text, isNot(contains('#609 Morning Run 9')));
      final firstPageButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(firstPageButtons, contains('🧾 #601 Morning Run 1'));
      expect(firstPageButtons, contains('🧾 #608 Morning Run 8'));
      expect(firstPageButtons, isNot(contains('🧾 #609 Morning Run 9')));
      expect(firstPageButtons, contains(MessageTemplates.buttonBookingsNextPage));
      expect(firstPageButtons, isNot(contains(MessageTemplates.buttonBookingsPreviousPage)));

      final secondPageHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonBookingsNextPage,
      });

      expect(secondPageHandled, isTrue);
      expect(sender.messages.last.text, contains('Страница <b>2/2</b>'));
      expect(sender.messages.last.text, contains('1. #609 Morning Run 9'));
      expect(sender.messages.last.text, isNot(contains('#608 Morning Run 8')));
      final secondPageButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(secondPageButtons, contains('🧾 #609 Morning Run 9'));
      expect(secondPageButtons, contains(MessageTemplates.buttonBookingsPreviousPage));
      expect(secondPageButtons, isNot(contains(MessageTemplates.buttonBookingsNextPage)));
    });

    test('hides passed bookings in active management list', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 1, archived: 2)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 701,
            userId: 9701,
            title: 'Future Run',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 702,
            userId: 9702,
            title: 'Past Run',
            startsAt: DateTime(2026, 9, 1, 10, 0),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 703,
            userId: 9703,
            title: 'Cancelled Run',
            startsAt: DateTime(2026, 10, 2, 10, 0),
            status: BookingStatus.cancelled,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2306},
        nowProvider: () => DateTime(2026, 9, 20, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2306},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2306},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2306},
        'text': '${MessageTemplates.buttonActiveBookings} (1)',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2306},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Future Run'));
      expect(sender.messages.last.text, isNot(contains('Past Run')));
      expect(sender.messages.last.text, isNot(contains('Cancelled Run')));
      expect(sender.messages.last.text, contains('всего записей: <b>1</b>'));
    });

    test('archives selected booking from admin management flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 0, archived: 1)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 501,
            userId: 9001,
            userUsername: 'archived_runner',
            trainingKey: 'trainings|2026-10-01T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Park',
            status: BookingStatus.pendingPayment,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2301},
        nowProvider: () => DateTime(2026, 10, 2, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '${MessageTemplates.buttonArchivedBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🧾 #501 Morning Run',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonDeleteBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonConfirmDeleteBooking,
      });
      final notifyHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonNotifyClientYes,
      });

      expect(handled, isTrue);
      expect(notifyHandled, isTrue);
      expect(bookingRepository.adminArchiveCalls, 1);
      expect(bookingRepository.lastAdminArchivedBookingId, 501);
      final userNotification = sender.messages.firstWhere((message) => message.chatId == 9001).text;
      expect(userNotification, contains('запись #501 отменил администратор'));
      expect(userNotification, contains('@dvor_support'));
      expect(sender.messages.last.text, contains('переведена в архив'));
    });

    test('reports client notification failure reason to admin', () async {
      final sender = _FakeSender()
        ..sendMessageFailuresByChatId[9001] = const TelegramApiException(
          'Forbidden: bot was blocked by the user',
          statusCode: 403,
        );
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 0, archived: 1)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 511,
            userId: 9001,
            userUsername: 'archived_runner',
            trainingKey: 'trainings|2026-10-01T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Park',
            status: BookingStatus.pendingPayment,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2311},
        nowProvider: () => DateTime(2026, 10, 2, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': '${MessageTemplates.buttonArchivedBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': '🧾 #511 Morning Run',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonDeleteBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonConfirmDeleteBooking,
      });
      final notifyHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2311},
        'text': MessageTemplates.buttonNotifyClientYes,
      });

      expect(notifyHandled, isTrue);
      final adminFailureMessage = sender.messages.firstWhere(
        (message) => message.chatId == 23 && message.text.contains('Клиента уведомить не удалось'),
      );
      expect(adminFailureMessage.text, contains('Forbidden: bot was blocked by the user'));
      expect(
        sender.messages.where((message) => message.chatId == 9001),
        isEmpty,
      );
    });

    test('restores archived booking when event is upcoming', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 0, archived: 1)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 502,
            userId: 9002,
            userUsername: 'restore_runner',
            trainingKey: 'trainings|2026-10-02T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 2, 10, 0),
            location: 'Park',
            status: BookingStatus.cancelled,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2303},
        nowProvider: () => DateTime(2026, 9, 30, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': '${MessageTemplates.buttonArchivedBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': '🧾 #502 Morning Run',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonRestoreBooking,
      });
      final notifyHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonNotifyClientNo,
      });

      expect(handled, isTrue);
      expect(notifyHandled, isTrue);
      expect(bookingRepository.adminBookings.single.status, BookingStatus.pendingPayment);
      expect(sender.messages.last.text, contains('восстановлена'));
    });

    test('shows conflict message when admin edit collides with existing booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 1, archived: 0)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 503,
            userId: -5003,
            userUsername: 'dup_runner',
            trainingKey: 'trainings|2026-10-03T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 3, 10, 0),
            location: 'Park',
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..throwAdminUpdateConflict = true;
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2304},
        nowProvider: () => DateTime(2026, 9, 30, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': '${MessageTemplates.buttonActiveBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': '🧾 #503 Morning Run',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonEditBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonEditBookingPayment,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonStatusFreeTraining,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('уже есть запись на выбранное мероприятие'));
    });

    test('creates booking from admin wizard', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Bootcamp',
        startsAt: DateTime(2026, 9, 18, 19, 0),
        location: 'Main Hall',
      );
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2302},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCreateBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🎯 1. Bootcamp',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '@new_runner',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonStatusFreeTraining,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonConfirmCreateBooking,
      });
      final notifyHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonNotifyClientNo,
      });

      expect(handled, isTrue);
      expect(notifyHandled, isTrue);
      expect(bookingRepository.adminBookings, hasLength(1));
      expect(bookingRepository.adminBookings.single.userUsername, 'new_runner');
      expect(bookingRepository.adminBookings.single.status, BookingStatus.freeTraining);
      expect(sender.messages.last.text, contains('создана'));
    });

    test('shows conflict message when admin create booking throws', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Paid Bootcamp',
        startsAt: DateTime(2026, 9, 18, 19, 0),
        location: 'Main Hall',
        price: 1800,
      );
      final bookingRepository = _FakeBookingRepository()..throwAdminCreateConflict = true;
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2302},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCreateBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🎯 1. Paid Bootcamp',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '@trainer_user',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonStatusFreeTraining,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonConfirmCreateBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.adminBookings, isEmpty);
      expect(sender.messages.last.text, contains('уже есть запись на выбранное мероприятие'));
    });

    test('notifies user and admin chat on approve payment', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1900},
        adminChatId: -100555,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 19, 'type': 'private'},
        'from': <String, dynamic>{'id': 1900, 'username': 'chief_admin'},
        'text': '/approve_payment 10',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('подтвердили'));
      expect(sender.messages[1].chatId, -100555);
      expect(sender.messages[1].text, contains('Модерация оплаты выполнена'));
      expect(sender.messages[1].text, contains('Пользователь: tg://user?id=1 (1)'));
      expect(sender.messages[1].text, contains('Проверил админ: @chief_admin (1900)'));
      expect(sender.messages[2].chatId, 19);
      expect(sender.messages[2].text, contains('Статус записи #10 обновлен'));
    });

    test('sends outdoor recap after approved payment for hike booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..paymentReviewResult = PaymentReviewResult(
          outcome: PaymentReviewOutcome.success,
          booking: _booking(
            id: 77,
            userId: 1777,
            title: '🥾 Поход: Архыз выходные',
            trainingKey: 'hikes|2026-10-15T00:00:00.000Z|🥾 Поход: Архыз выходные|Маршрут',
            startsAt: DateTime(2026, 10, 15, 8, 0),
            location: 'Маршрут',
            status: BookingStatus.paid,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Архыз выходные',
              dateFrom: DateTime(2026, 10, 15),
              dateTo: DateTime(2026, 10, 16, 23, 59, 59),
              description: 'Маршрут 2 дня',
              equipment: 'Ботинки, дождевик, вода',
              itinerary: 'Сбор в 06:00, выезд в 06:30',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1901},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1901, 'type': 'private'},
        'from': <String, dynamic>{'id': 1901},
        'text': '/approve_payment 77',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(4));
      expect(sender.messages[0].chatId, 1777);
      expect(sender.messages[0].text, contains('Оплата подтверждена'));
      expect(sender.messages[1].chatId, 1777);
      expect(sender.messages[1].text, contains('Расписание похода'));
      expect(sender.messages[1].text, contains('Сбор в 06:00, выезд в 06:30'));
      expect(sender.messages[2].chatId, 1777);
      expect(sender.messages[2].text, contains('Экипировка'));
      expect(sender.messages[2].text, contains('Ботинки, дождевик, вода'));
      expect(sender.messages[3].chatId, 1901);
      expect(sender.messages[3].text, contains('Статус записи #77 обновлен'));
    });

    test('handles payment moderation callback buttons for admin', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1950},
        adminChatId: -100556,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-1',
          'from': <String, dynamic>{'id': 1950, 'username': 'moderator_anna'},
          'data': '${MessageTemplates.callbackRejectPaymentPrefix}22',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1950, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('отклонили'));
      expect(sender.messages[1].chatId, -100556);
      expect(sender.messages[1].text, contains('Проверил админ: @moderator_anna (1950)'));
      expect(sender.messages[2].chatId, 1950);
      expect(sender.messages[2].text, contains('Статус записи #22 обновлен'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-1');
    });

    test('handles partial payment moderation callback buttons for admin', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1955},
        adminChatId: -100559,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-partial',
          'from': <String, dynamic>{'id': 1955, 'username': 'moderator_olga'},
          'data': '${MessageTemplates.callbackApprovePartialPaymentPrefix}25',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1955, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('Предоплату по записи #25 подтвердили'));
      expect(sender.messages[1].chatId, -100559);
      expect(sender.messages[1].text, contains('Статус: Предоплата внесена 🟡'));
      expect(sender.messages[2].chatId, 1955);
      expect(sender.messages[2].text, contains('Предоплата внесена 🟡'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-partial');
    });

    test('shows already reviewed message when payment status is stale', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..paymentReviewResult = const PaymentReviewResult(
          outcome: PaymentReviewOutcome.invalidStatus,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1990},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1990, 'type': 'private'},
        'from': <String, dynamic>{'id': 1990},
        'text': '/approve_payment 22',
      });

      expect(handled, isTrue);
      expect(bookingRepository.reviewCalls, 1);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('уже не в статусе «На проверке»'));
    });

    test('opens payments queue flow from admin notification callback', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1952},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-open-queue',
          'from': <String, dynamic>{'id': 1952},
          'data': MessageTemplates.callbackOpenPaymentsQueue,
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1952, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 1952);
      expect(sender.messages.single.text, contains('Очередь заявок на оплату'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-open-queue');
    });

    test('payment moderation callback is not treated as training selection', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Admin training',
              startsAt: DateTime(2026, 7, 15, 19, 0),
              location: 'Main Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1951},
        adminChatId: -100557,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1951, 'type': 'private'},
        'from': <String, dynamic>{'id': 1951},
        'text': '/book',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-2',
          'from': <String, dynamic>{'id': 1951},
          'data': '${MessageTemplates.callbackApprovePaymentPrefix}23',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1951, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages.any((message) => message.text.contains('Не понял выбор')), isFalse);
      expect(sender.messages.last.chatId, 1951);
      expect(sender.messages.last.text, contains('Статус записи #23 обновлен'));
    });

    test('shows outdoor payment choice buttons in payment flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 930,
            userId: 3930,
            title: '🏃 Трейл: Приэльбрусье',
            trainingKey: 'trails|2026-10-01T10:00:00.000Z|🏃 Трейл: Приэльбрусье|Маршрут',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.pendingPayment,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3930, 'type': 'private'},
        'from': <String, dynamic>{'id': 3930},
        'text': MessageTemplates.buttonSubmitPayment,
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonPayPartially));
      expect(buttons, contains(MessageTemplates.buttonPayFully));
      expect(buttons, contains(MessageTemplates.buttonSubmitPayment));
    });

    test('opens top-up flow for partial paid booking without payment type choice', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 931,
            userId: 3931,
            title: '🏃 Трейл: Приэльбрусье',
            trainingKey: 'trails|2026-10-01T10:00:00.000Z|🏃 Трейл: Приэльбрусье|Маршрут',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.partialPaid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3931, 'type': 'private'},
        'from': <String, dynamic>{'id': 3931},
        'text': MessageTemplates.buttonSubmitPayment,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Предоплату по записи #931 уже зафиксировали'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, isNot(contains(MessageTemplates.buttonPayFully)));
      expect(buttons, isNot(contains(MessageTemplates.buttonPayPartially)));
      expect(buttons, contains(MessageTemplates.buttonSubmitPayment));
    });

    test('shows dedicated top-up action for partial paid booking in profile', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 932,
            userId: 3932,
            title: '🥾 Поход: Архыз',
            trainingKey: 'hikes|2026-10-02T10:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            startsAt: DateTime(2026, 10, 2, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.partialPaid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3932, 'type': 'private'},
        'from': <String, dynamic>{'id': 3932},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3932, 'type': 'private'},
        'from': <String, dynamic>{'id': 3932},
        'text': '🧾 #932 🥾 Поход: Архыз',
      });

      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonCompletePayment));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3932, 'type': 'private'},
        'from': <String, dynamic>{'id': 3932},
        'text': MessageTemplates.buttonCompletePayment,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Предоплату по записи #932 уже зафиксировали'));
    });

    test('repeat booking action opens booking flow for same category', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 3901,
            title: '🥾 Поход: Архыз',
            trainingKey: 'hikes|2026-10-01T10:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Архыз выходные',
              dateFrom: DateTime(2026, 10, 15),
              dateTo: DateTime(2026, 10, 16, 23, 59, 59),
              description: 'Маршрут 2 дня',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': '🧾 #901 🥾 Поход: Архыз',
      });

      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonRepeatBooking));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': MessageTemplates.buttonRepeatBooking,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Выбери мероприятие для записи'));
      expect(sender.messages.last.text, contains('🥾 Поход: Архыз выходные'));
    });

    test('opens and sends economic summary by selected period', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          TrainingBooking(
            id: 99,
            userId: 7001,
            userUsername: 'admin_econ',
            trainingKey: 'trainings|summary',
            trainingTitle: 'Test event',
            startsAt: DateTime(2026, 11, 2, 19),
            location: 'Hall',
            status: BookingStatus.paid,
            trainingPrice: 1200,
            createdAt: DateTime(2026, 11, 2, 18),
            updatedAt: DateTime(2026, 11, 2, 20),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{4902},
        nowProvider: () => DateTime(2026, 11, 10, 12),
      );

      final openHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4902, 'type': 'private'},
        'from': <String, dynamic>{'id': 4902},
        'text': MessageTemplates.buttonEconomicSummary,
      });
      expect(openHandled, isTrue);
      expect(sender.messages.single.text, contains('Выбери период'));

      final sendHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4902, 'type': 'private'},
        'from': <String, dynamic>{'id': 4902},
        'text': MessageTemplates.buttonSummaryPreviousWeek,
      });
      expect(sendHandled, isTrue);
      expect(sender.messages.last.text, contains('Экономическая сводка'));
      expect(sender.messages.last.text, contains('Финансы:'));
    });

    test('supports economic summary command with period argument', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          TrainingBooking(
            id: 100,
            userId: 7002,
            userUsername: 'admin_econ_cmd',
            trainingKey: 'trainings|summary2',
            trainingTitle: 'Cmd event',
            startsAt: DateTime(2026, 11, 3, 19),
            location: 'Hall',
            status: BookingStatus.paid,
            trainingPrice: 1500,
            createdAt: DateTime(2026, 11, 3, 18),
            updatedAt: DateTime(2026, 11, 3, 20),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{4903},
        nowProvider: () => DateTime(2026, 11, 10, 12),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4903, 'type': 'private'},
        'from': <String, dynamic>{'id': 4903},
        'text': '/economic_summary current_month',
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('за текущий месяц'));
    });
  });

  group('PrivateHandlers promo code flow', () {
    Future<PrivateHandlers> openPaymentConfirmation({
      required _FakeSender sender,
      required _FakeBookingRepository bookingRepository,
      required _FakePromoCodeRepository promoCodeRepository,
      required int chatId,
      required int userId,
      int price = 1500,
      int? adminChatId,
    }) async {
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Promo session',
              startsAt: DateTime(2026, 7, 20, 19, 0),
              location: 'Hall',
              price: price,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        promoCodeRepository: promoCodeRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: adminChatId,
      );
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
        'from': <String, dynamic>{'id': userId},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
        'from': <String, dynamic>{'id': userId},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
        'from': <String, dynamic>{'id': userId},
        'text': '🎯 1. Promo session',
      });
      return handlers;
    }

    test('shows promo code button when booking price is positive', () async {
      final sender = _FakeSender();
      await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: _FakePromoCodeRepository(const <PromoCode>[]),
        chatId: 2101,
        userId: 3101,
      );

      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonEnterPromoCode));
    });

    test('entering promo code button asks for the code text', () async {
      final sender = _FakeSender();
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: _FakePromoCodeRepository(const <PromoCode>[]),
        chatId: 2102,
        userId: 3102,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2102, 'type': 'private'},
        'from': <String, dynamic>{'id': 3102},
        'text': MessageTemplates.buttonEnterPromoCode,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Введи текст промокода'));
      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonBack));
    });

    test('applies partial discount promo code and shows new amount', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final promoCodeRepository = _FakePromoCodeRepository(const <PromoCode>[
        PromoCode(code: 'SUMMER50', discountPercent: 50),
      ]);
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: bookingRepository,
        promoCodeRepository: promoCodeRepository,
        chatId: 2103,
        userId: 3103,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2103, 'type': 'private'},
        'from': <String, dynamic>{'id': 3103},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2103, 'type': 'private'},
        'from': <String, dynamic>{'id': 3103},
        'text': 'summer50',
      });

      expect(handled, isTrue);
      expect(bookingRepository.applyPromoCodeCalls, 1);
      expect(bookingRepository.lastPromoCode, 'SUMMER50');
      expect(bookingRepository.lastPromoDiscountPercent, 50);
      expect(bookingRepository.lastPromoDiscountedPrice, 750);
      expect(sender.messages.last.text, contains('SUMMER50'));
      expect(sender.messages.last.text, contains('−50%'));

      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, isNot(contains(MessageTemplates.buttonEnterPromoCode)));
    });

    test('applies full discount promo code and marks booking free', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final promoCodeRepository = _FakePromoCodeRepository(const <PromoCode>[
        PromoCode(code: 'FREEDAY', discountPercent: 100),
      ]);
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: bookingRepository,
        promoCodeRepository: promoCodeRepository,
        chatId: 2104,
        userId: 3104,
        adminChatId: -100999,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2104, 'type': 'private'},
        'from': <String, dynamic>{'id': 3104},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2104, 'type': 'private'},
        'from': <String, dynamic>{'id': 3104},
        'text': 'FREEDAY',
      });

      expect(handled, isTrue);
      expect(bookingRepository.lastPromoDiscountedPrice, 0);
      expect(sender.messages.last.text, contains('бесплатна'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100999).text;
      expect(adminMessage, contains('Применен промокод'));
    });

    test('rejects unknown promo code and returns to payment confirmation', () async {
      final sender = _FakeSender();
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: _FakePromoCodeRepository(const <PromoCode>[]),
        chatId: 2105,
        userId: 3105,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2105, 'type': 'private'},
        'from': <String, dynamic>{'id': 3105},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2105, 'type': 'private'},
        'from': <String, dynamic>{'id': 3105},
        'text': 'DOES_NOT_EXIST',
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Такого промокода не нашел'));
      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonEnterPromoCode));
    });

    test('rejects promo code that does not apply to booking category', () async {
      final sender = _FakeSender();
      final promoCodeRepository = _FakePromoCodeRepository(const <PromoCode>[
        PromoCode(
          code: 'YOGAONLY',
          discountPercent: 20,
          categories: <ActivityCategory>{ActivityCategory.yoga},
        ),
      ]);
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: promoCodeRepository,
        chatId: 2106,
        userId: 3106,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2106, 'type': 'private'},
        'from': <String, dynamic>{'id': 3106},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2106, 'type': 'private'},
        'from': <String, dynamic>{'id': 3106},
        'text': 'YOGAONLY',
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('не действует для выбранного типа'));
    });

    test('back button from promo code entry returns to payment confirmation', () async {
      final sender = _FakeSender();
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: _FakePromoCodeRepository(const <PromoCode>[]),
        chatId: 2107,
        userId: 3107,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2107, 'type': 'private'},
        'from': <String, dynamic>{'id': 3107},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2107, 'type': 'private'},
        'from': <String, dynamic>{'id': 3107},
        'text': MessageTemplates.buttonBack,
      });

      expect(handled, isTrue);
      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonEnterPromoCode));
    });

    test('does not show promo code button once booking is free', () async {
      final sender = _FakeSender();
      await openPaymentConfirmation(
        sender: sender,
        bookingRepository: _FakeBookingRepository(),
        promoCodeRepository: _FakePromoCodeRepository(const <PromoCode>[]),
        chatId: 2108,
        userId: 3108,
        price: 0,
      );

      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, isNot(contains(MessageTemplates.buttonEnterPromoCode)));
    });

    test('rejects single-use promo code that has already been used', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()..promoCodeAlreadyUsed = true;
      final promoCodeRepository = _FakePromoCodeRepository(const <PromoCode>[
        PromoCode(code: 'ONCE', discountPercent: 50, singleUse: true),
      ]);
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: bookingRepository,
        promoCodeRepository: promoCodeRepository,
        chatId: 2109,
        userId: 3109,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2109, 'type': 'private'},
        'from': <String, dynamic>{'id': 3109},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2109, 'type': 'private'},
        'from': <String, dynamic>{'id': 3109},
        'text': 'ONCE',
      });

      expect(handled, isTrue);
      expect(bookingRepository.applyPromoCodeCalls, 0);
      expect(sender.messages.last.text, contains('уже был использован'));
      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonEnterPromoCode));
    });

    test('allows single-use promo code when not yet used', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()..promoCodeAlreadyUsed = false;
      final promoCodeRepository = _FakePromoCodeRepository(const <PromoCode>[
        PromoCode(code: 'ONCE', discountPercent: 50, singleUse: true),
      ]);
      final handlers = await openPaymentConfirmation(
        sender: sender,
        bookingRepository: bookingRepository,
        promoCodeRepository: promoCodeRepository,
        chatId: 2110,
        userId: 3110,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2110, 'type': 'private'},
        'from': <String, dynamic>{'id': 3110},
        'text': MessageTemplates.buttonEnterPromoCode,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2110, 'type': 'private'},
        'from': <String, dynamic>{'id': 3110},
        'text': 'ONCE',
      });

      expect(handled, isTrue);
      expect(bookingRepository.applyPromoCodeCalls, 1);
      expect(sender.messages.last.text, contains('ONCE'));
    });
  });

  group('admin broadcast with photos', () {
    test('broadcasts a single photo via copyMessage', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository()
        ..seedUser(userId: 501)
        ..seedUser(userId: 502);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9001},
        targetChatId: -1009001,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9001, 'type': 'private'},
        'from': <String, dynamic>{'id': 9001},
        'text': MessageTemplates.buttonBroadcast,
      });
      await handlers.handle(
        privatePhotoMessageUpdate(
          chatId: 9001,
          userId: 9001,
          messageId: 77,
          caption: 'Анонс',
        ),
      );
      final handled = await handlers.handle(
        privateCallbackUpdate(
          callbackId: 'cb-broadcast-users',
          chatId: 9001,
          userId: 9001,
          data: MessageCopy.callbackBroadcastToUsers,
        ),
      );

      expect(handled, isTrue);
      expect(sender.copiedMessages, hasLength(2));
      expect(
        sender.copiedMessages.map((item) => item.toChatId).toSet(),
        <int>{501, 502},
      );
      expect(
        sender.copiedMessages.every(
          (item) => item.fromChatId == 9001 && item.messageId == 77,
        ),
        isTrue,
      );
      expect(sender.messages.last.text, contains('Рассылка завершена'));
    });

    test('broadcasts a photo album after media group is collected', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository()..seedUser(userId: 601);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9002},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9002, 'type': 'private'},
        'from': <String, dynamic>{'id': 9002},
        'text': MessageTemplates.buttonBroadcast,
      });
      await handlers.handle(
        privatePhotoMessageUpdate(
          chatId: 9002,
          userId: 9002,
          messageId: 11,
          mediaGroupId: 'album-1',
        ),
      );
      await handlers.handle(
        privatePhotoMessageUpdate(
          chatId: 9002,
          userId: 9002,
          messageId: 12,
          mediaGroupId: 'album-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(
        sender.messages.any((item) => item.text.contains('Предпросмотр рассылки')),
        isTrue,
      );

      final handled = await handlers.handle(
        privateCallbackUpdate(
          callbackId: 'cb-broadcast-album',
          chatId: 9002,
          userId: 9002,
          data: MessageCopy.callbackBroadcastToUsers,
        ),
      );

      expect(handled, isTrue);
      expect(sender.copiedMessages, hasLength(2));
      expect(
        sender.copiedMessages.map((item) => item.messageId).toList(),
        <int>[11, 12],
      );
    });
  });
}
