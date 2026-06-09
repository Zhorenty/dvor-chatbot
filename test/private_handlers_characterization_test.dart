import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/private_handlers_harness.dart';

void main() {
  group('PrivateHandlers characterization', () {
    test('start keeps welcome and pin behavior', () async {
      final harness = PrivateHandlersHarness();

      final handled = await harness.handleText(
        chatId: 1100,
        userId: 1100,
        text: '/start',
      );

      expect(handled, isTrue);
      expect(harness.sender.messages, hasLength(1));
      expect(harness.sender.messages.single.text, contains('Добро пожаловать в DVOR'));
      expect(harness.sender.pinnedMessages, hasLength(1));
      expect(harness.sender.pinnedMessages.single.chatId, 1100);
      expect(harness.sender.pinnedMessages.single.messageId, 1);
    });

    test('book flow by textual selection creates pending booking', () async {
      final harness = PrivateHandlersHarness(
        trainings: <TrainingInfo>[
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
      );

      await harness.handleText(
        chatId: 161,
        userId: 1601,
        text: '/book',
      );
      await harness.handleText(
        chatId: 161,
        userId: 1601,
        text: MessageTemplates.buttonCategoryTrainings,
      );
      final handled = await harness.handleText(
        chatId: 161,
        userId: 1601,
        username: 'second_user',
        text: '🎯 2. Second session',
      );

      expect(handled, isTrue);
      expect(harness.booking.createCalls, 1);
      expect(harness.booking.lastCreatedTraining?.title, 'Second session');
      expect(harness.booking.lastCreatedUsername, 'second_user');
      expect(harness.sender.messages.last.text, contains('записал тебя'));
    });

    test('quick book from viewed category keeps context', () async {
      final harness = PrivateHandlersHarness(
        outdoorActivities: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Поход на Бзерпинский карниз',
            dateFrom: DateTime(2026, 7, 20),
            dateTo: DateTime(2026, 7, 21, 23, 59, 59),
            description: 'Двухдневный маршрут',
            price: 4100,
          ),
        ],
      );

      await harness.handleText(
        chatId: 1610,
        userId: 1610,
        text: MessageTemplates.buttonTrainings,
      );
      await harness.handleText(
        chatId: 1610,
        userId: 1610,
        text: MessageTemplates.buttonCategoryHikes,
      );
      final handled = await harness.handleText(
        chatId: 1610,
        userId: 1610,
        text: MessageTemplates.buttonBookTraining,
      );

      expect(handled, isTrue);
      expect(harness.sender.messages.last.text, contains('выбери мероприятие для записи'));
      expect(harness.sender.messages.last.text, contains('🥾 Поход: Поход на Бзерпинский карниз'));
    });

    test('payment moderation callback keeps callback and notifications behavior', () async {
      final harness = PrivateHandlersHarness(
        adminUserIds: const <int>{1950},
        adminChatId: -100556,
      );

      final handled = await harness.handleCallback(
        callbackId: 'cbq-1',
        chatId: 1950,
        userId: 1950,
        username: 'moderator_anna',
        data: '${MessageTemplates.callbackRejectPaymentPrefix}22',
      );

      expect(handled, isTrue);
      expect(harness.sender.messages, hasLength(3));
      expect(harness.sender.messages[0].chatId, 1);
      expect(harness.sender.messages[1].chatId, -100556);
      expect(harness.sender.messages[2].chatId, 1950);
      expect(harness.sender.answeredCallbacks, hasLength(1));
      expect(harness.sender.answeredCallbacks.single.callbackQueryId, 'cbq-1');
    });
  });
}
