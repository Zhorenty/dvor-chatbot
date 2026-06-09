import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/economic_summary_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('sends weekly and monthly reports once per period', () async {
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 1,
          status: BookingStatus.paid,
          trainingKey: 'trainings|1',
          title: 'Функционал',
          trainingPrice: 1000,
          updatedAt: DateTime(2026, 6, 2, 12),
        ),
      ];
    final sender = FakeSender();
    final scheduleRepository = FakeScheduleRepository(const []);
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
    );
    final job = EconomicSummaryJob(
      bookingRepository: bookingRepository,
      economicSummaryService: service,
      sender: sender,
      templates: const MessageTemplates(),
      adminChatId: 999,
      nowProvider: () => DateTime(2026, 6, 9, 12),
    );

    await job.run();
    await job.run();

    expect(sender.messages, hasLength(2));
    expect(sender.messages[0].chatId, 999);
    expect(sender.messages[0].text, contains('Экономическая сводка'));
    expect(sender.messages[1].text, contains('Экономическая сводка'));
  });

  test('retries report on next run after send failure', () async {
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 1,
          status: BookingStatus.paid,
          trainingKey: 'trainings|1',
          title: 'Функционал',
          trainingPrice: 1000,
          updatedAt: DateTime(2026, 6, 2, 12),
        ),
      ];
    final sender = _FlakySender(failuresBeforeSuccess: 1);
    final scheduleRepository = FakeScheduleRepository(const []);
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
    );
    final job = EconomicSummaryJob(
      bookingRepository: bookingRepository,
      economicSummaryService: service,
      sender: sender,
      templates: const MessageTemplates(),
      adminChatId: 999,
      nowProvider: () => DateTime(2026, 6, 9, 12),
    );

    await job.run();
    await job.run();

    expect(sender.successfulSends, 2);
  });
}

final class _FlakySender implements MessageSender {
  _FlakySender({required int failuresBeforeSuccess}) : _remainingFailures = failuresBeforeSuccess;

  int _remainingFailures;
  int successfulSends = 0;

  @override
  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  }) async {}

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) async {
    return 0;
  }

  @override
  Future<void> deleteMessage(
    int chatId, {
    required int messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    int chatId, {
    required int messageId,
    bool disableNotification = true,
  }) async {}

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) async {
    if (_remainingFailures > 0) {
      _remainingFailures--;
      throw StateError('temporary telegram error');
    }
    successfulSends++;
    return successfulSends;
  }
}
