import 'dart:io';

import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/memory_loyalty_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/domain/booking_attendance.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/attendance_reminder_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('attendance reminder sends one daily digest of open trainings', () async {
    // 10:00 business time (UTC+3).
    final start = DateTime.utc(2026, 10, 12, 7);
    final bookings = FakeBookingRepository()
      ..userBookings = [
        fakeBooking(
          id: 1,
          status: BookingStatus.paid,
          title: 'Силовая',
          trainingKey: 'trainings|power',
          startsAt: start,
        ),
        fakeBooking(
          id: 2,
          status: BookingStatus.paid,
          title: 'Силовая',
          trainingKey: 'trainings|power',
          startsAt: start,
          attendance: BookingAttendance.attended,
        ),
        fakeBooking(
          id: 3,
          status: BookingStatus.paid,
          title: 'Бокс',
          trainingKey: 'trainings|boxing',
          startsAt: start.add(const Duration(hours: 1)),
        ),
      ];
    final sender = FakeSender();
    final tmpDir = await Directory.systemTemp.createTemp('attendance-dedupe-');
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });
    final handle = SqliteDatabaseHandle.open('${tmpDir.path}/jobs.sqlite');
    addTearDown(handle.close);
    var now = start.add(const Duration(hours: 1));
    final dedupe = JobDedupeRepository(databaseHandle: handle, nowProvider: () => now)
      ..initSchema();
    final job = AttendanceReminderJob(
      bookingRepository: bookings,
      sender: sender,
      templates: const MessageTemplates(),
      adminChatId: 42,
      jobDedupeRepository: dedupe,
      nowProvider: () => now,
    );

    await job.run();
    expect(sender.messages, isEmpty);

    now = start.add(const Duration(hours: 2));
    await job.run();
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, 42);
    expect(sender.messages.single.text, contains('по 1 тренировке'));
    expect(sender.messages.single.text, contains('Силовая'));
    expect(sender.messages.single.text, isNot(contains('Бокс')));

    // Another training becomes due the same day: no second message.
    now = start.add(const Duration(hours: 4));
    await job.run();
    expect(sender.messages, hasLength(1));

    // Next business day (00:30 UTC+3): one digest with both trainings.
    now = DateTime.utc(2026, 10, 12, 21, 30);
    await job.run();
    expect(sender.messages, hasLength(2));
    expect(sender.messages.last.text, contains('по 2 тренировкам'));
    expect(sender.messages.last.text, contains('Силовая'));
    expect(sender.messages.last.text, contains('Бокс'));

    await job.run();
    expect(sender.messages, hasLength(2));
  });

  test('attendance reminder skips a session once everyone is marked', () async {
    final start = DateTime(2026, 10, 12, 10);
    final bookings = FakeBookingRepository()
      ..userBookings = [
        fakeBooking(
          id: 3,
          status: BookingStatus.paid,
          trainingKey: 'trainings|done',
          startsAt: start,
          attendance: BookingAttendance.absent,
        ),
      ];
    final sender = FakeSender();
    final job = AttendanceReminderJob(
      bookingRepository: bookings,
      sender: sender,
      templates: const MessageTemplates(),
      adminChatId: 42,
      nowProvider: () => start.add(const Duration(hours: 3)),
    );

    await job.run();
    expect(sender.messages, isEmpty);
  });

  test('admin grants peaks from the tools button and the user is notified', () async {
    final now = DateTime.utc(2026, 10, 12, 9);
    final loyalty = LoyaltyService(
      repository: InMemoryLoyaltyRepository(nowProvider: () => now),
      nowProvider: () => now,
    );
    final sender = FakeSender();
    final handlers = PrivateHandlers(
      sender: sender,
      scheduleRepository: FakeScheduleRepository(const <TrainingInfo>[]),
      bookingRepository: FakeBookingRepository(),
      templates: const MessageTemplates(),
      adminUserIds: const <int>{7},
      loyaltyService: loyalty,
      nowProvider: () => now,
    );

    await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 7, 'type': 'private'},
      'from': <String, dynamic>{'id': 7},
      'text': MessageTemplates.buttonAdminTools,
    });
    await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 7, 'type': 'private'},
      'from': <String, dynamic>{'id': 7},
      'text': MessageTemplates.buttonAdminLoyaltyGrant,
    });
    expect(sender.lastContentMessage.text, contains('Кому начислить'));

    await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 7, 'type': 'private'},
      'from': <String, dynamic>{'id': 7},
      'text': '15',
    });
    expect(sender.lastContentMessage.text, contains('Сколько начислить'));

    await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 7, 'type': 'private'},
      'from': <String, dynamic>{'id': 7},
      'text': '7',
    });
    expect(sender.lastContentMessage.text, contains('кратна 10'));

    await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 7, 'type': 'private'},
      'from': <String, dynamic>{'id': 7},
      'text': '50',
    });

    expect((await loyalty.account(15)).remaining, 50);
    expect(
      sender.messages.any(
        (message) => message.chatId == 7 && message.text.contains('Начислил 50'),
      ),
      isTrue,
    );
    expect(
      sender.messages.any(
        (message) => message.chatId == 15 && message.text.contains('+50'),
      ),
      isTrue,
    );
  });
}
