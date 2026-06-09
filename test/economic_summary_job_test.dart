import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/economic_summary_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
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
}
