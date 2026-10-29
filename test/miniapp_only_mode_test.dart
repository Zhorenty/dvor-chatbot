import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';
import 'support/telegram_fixtures.dart';

const String _appUrl = 'https://app.example/';
const int _member = 41;
const int _admin = 900;

Map<String, Object?>? _webAppButton(Map<String, Object?>? markup) {
  final rows = markup?['inline_keyboard'];
  if (rows is! List || rows.isEmpty) {
    return null;
  }
  final first = (rows.first as List).first as Map<String, Object?>;
  return first['web_app'] == null ? null : first;
}

void main() {
  final now = DateTime.utc(2026, 10, 20, 9);
  final training = TrainingInfo(
    title: 'Бокс',
    startsAt: DateTime.utc(2026, 10, 22, 16),
    location: 'Зал',
    price: 600,
  );

  PrivateHandlersHarness harness({FakeBookingRepository? bookings}) => PrivateHandlersHarness(
        trainings: [training],
        bookingRepository: bookings,
        adminUserIds: const {_admin},
        nowProvider: () => now,
        templates: const MessageTemplates(miniAppUrl: _appUrl),
      );

  test('/start answers with an Open DVOR button and keeps onboarding state', () async {
    final h = harness();
    await h.handleText(chatId: _member, userId: _member, text: '/start ref_77');

    final sent = h.messagesTo(_member);
    final welcome = sent.last;
    expect(welcome.text, contains('в приложении'));
    final button = _webAppButton(welcome.replyMarkup);
    expect(button?['text'], 'Открыть DVOR');
    expect((button?['web_app'] as Map<String, Object?>?)?['url'], _appUrl);
    expect(h.onboarding.referralInviterByInvitee[_member], 77);
  });

  test('old menu buttons and free text point to the app and clear the keyboard', () async {
    final h = harness();
    await h.handleText(chatId: _member, userId: _member, text: MessageCopy.buttonBookTraining);

    final reply = h.messagesTo(_member).single;
    expect(reply.text, contains('Всё теперь в приложении'));
    expect(reply.replyMarkup, {'remove_keyboard': true});
    expect(h.booking.createCalls, 0);
  });

  test('inline CTA that used to open the chat menu opens the app instead', () async {
    final h = harness();
    await h.handleCallback(
      callbackId: 'cb1',
      chatId: _member,
      userId: _member,
      data: MessageCopy.callbackCtaBook,
    );
    expect(_webAppButton(h.messagesTo(_member).last.replyMarkup), isNotNull);
  });

  test('receipts sent as photos still reach the payment flow', () async {
    final bookings = FakeBookingRepository()
      ..userBookings = [
        fakeBooking(
          id: 5,
          userId: _member,
          trainingKey: training.sessionKey,
          status: BookingStatus.pendingPayment,
          trainingPrice: 600,
        ),
      ];
    final h = harness(bookings: bookings);
    await h
        .handleUpdate(privatePhotoMessageUpdate(chatId: _member, userId: _member, messageId: 70));
    expect(
      h.messagesTo(_member).any((m) => m.text.contains('Всё теперь в приложении')),
      isFalse,
    );
  });

  test('admins keep the chat menu', () async {
    final h = harness();
    await h.handleText(chatId: _admin, userId: _admin, text: '/start');
    final last = h.messagesTo(_admin).last;
    expect(_webAppButton(last.replyMarkup), isNull);
  });

  test('app actions still drive chat flows in Mini App mode', () async {
    final bookings = FakeBookingRepository()
      ..userBookings = [
        fakeBooking(
          id: 12,
          userId: _member,
          trainingKey: training.sessionKey,
          status: BookingStatus.paid,
          trainingPrice: 600,
          startsAt: training.startsAt,
        ),
      ];
    final second = TrainingInfo(
      title: 'Силовая',
      startsAt: DateTime.utc(2026, 10, 23, 16),
      location: 'Зал',
      price: 600,
    );
    final h = PrivateHandlersHarness(
      trainings: [training, second],
      bookingRepository: bookings,
      nowProvider: () => now,
      templates: const MessageTemplates(miniAppUrl: _appUrl),
    );
    await h.handlers.miniAppRpc(
      'booking.reschedule',
      const MiniAppCaller(id: _member, username: 'runner'),
      {'bookingId': 12, 'key': second.sessionKey},
    );
    expect(bookings.lastRescheduledBookingId, 12);
  });
}
