import 'package:dvor_miniapp/app.dart';
import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/repository.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final DateTime _now = DateTime.utc(2026, 10, 28, 9);

class _FakeRepository implements DvorRepository {
  final List<String> booked = <String>[];
  ApiException? bookError;

  final List<ClubEvent> _events = [
    ClubEvent(
      key: 'box',
      category: EventCategory.trainings,
      title: 'Бокс',
      startsAt: DateTime.utc(2026, 10, 29, 16, 30),
      location: 'Зал',
      price: 700,
      limit: 10,
      taken: 8,
    ),
    ClubEvent(
      key: 'hike',
      category: EventCategory.hikes,
      title: 'Поход выходного дня',
      startsAt: DateTime.utc(2026, 11, 7, 4),
      endsAt: DateTime.utc(2026, 11, 8, 16),
      location: 'Маршрут',
      price: 6000,
      prepayPercent: 50,
    ),
  ];

  @override
  Future<Me> me() async => const Me(id: 1, firstName: 'Аня', peaks: 120, botUsername: 'dvor_bot');

  @override
  Future<List<ClubEvent>> events() async => _events;

  @override
  Future<List<Booking>> bookings() async => const [];

  @override
  Future<ActionResult> book(String key) async {
    final error = bookError;
    if (error != null) {
      throw error;
    }
    booked.add(key);
    final event = _events.firstWhere((e) => e.key == key);
    return ActionResult(
      outcome: ActionOutcome.created,
      booking: Booking(
        id: 5,
        key: key,
        category: event.category,
        title: event.title,
        startsAt: event.startsAt,
        location: event.location,
        status: BookingStatus.pendingPayment,
      ),
    );
  }

  @override
  Future<ActionResult> cancel(int bookingId) async =>
      const ActionResult(outcome: ActionOutcome.cancelled);
}

Future<(_FakeRepository, StubTelegramPlatform)> _pump(WidgetTester tester) async {
  await initializeDateFormatting('ru');
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = _FakeRepository();
  final tg = StubTelegramPlatform();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        telegramProvider.overrideWithValue(tg),
        repositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: DvorApp(router: buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, tg);
}

void main() {
  testWidgets('schedule groups events by day and filters by category', (tester) async {
    await _pump(tester);
    expect(find.text('АФИША'), findsOneWidget);
    expect(find.text('БОКС'), findsOneWidget);
    expect(find.text('ЗАВТРА'), findsOneWidget);
    expect(find.text('Осталось 2 места'), findsOneWidget);
    expect(find.text('ПОХОД ВЫХОДНОГО ДНЯ'), findsOneWidget);

    await tester.tap(find.text('Походы'));
    await tester.pumpAndSettle();
    expect(find.text('БОКС'), findsNothing);
    expect(find.text('ПОХОД ВЫХОДНОГО ДНЯ'), findsOneWidget);
  });

  testWidgets('booking shows the payment sheet and opens the bot chat', (tester) async {
    final (repo, tg) = await _pump(tester);
    await tester.tap(find.text('БОКС'));
    await tester.pumpAndSettle();
    expect(find.text('Записаться · 700 ₽'), findsOneWidget);

    await tester.tap(find.text('Записаться · 700 ₽'));
    await tester.pumpAndSettle();
    expect(repo.booked, ['box']);
    expect(find.text('МЕСТО ЗА ТОБОЙ'), findsOneWidget);

    await tester.tap(find.text('Перейти к оплате'));
    await tester.pumpAndSettle();
    expect(tg.openedLinks, ['https://t.me/dvor_bot']);
  });

  testWidgets('booking errors are shown to the user', (tester) async {
    final (repo, _) = await _pump(tester);
    repo.bookError = const ApiException('full', 'Мест уже нет.');
    await tester.tap(find.text('БОКС'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Записаться · 700 ₽'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Мест уже нет.'), findsOneWidget);
  });

  test('models parse API payloads', () {
    final event = ClubEvent.fromJson({
      'key': 'k',
      'category': 'trails',
      'title': ' Трейл ',
      'startsAt': '2026-11-01T06:00:00.000Z',
      'endsAt': '2026-11-02T15:00:00.000Z',
      'location': 'Гора',
      'price': 0,
      'limit': 5,
      'taken': 7,
      'notes': '  ',
    });
    expect(event.category, EventCategory.trails);
    expect(event.title, 'Трейл');
    expect(event.isFree, isTrue);
    expect(event.seatsLeft, 0);
    expect(event.notes, isNull);
    expect(event.isMultiDay, isTrue);

    final booking = Booking.fromJson({
      'id': 3,
      'key': 'k',
      'category': 'trainings',
      'title': 'Бокс',
      'startsAt': '2026-11-01T16:00:00.000Z',
      'location': 'Зал',
      'status': 'payment_rejected',
      'canCancel': true,
      'attendance': 'attended',
    });
    expect(booking.status.needsPayment, isTrue);
    expect(booking.status.isActive, isFalse);
    expect(booking.attended, isTrue);
  });

  test('russian plurals and prices', () {
    expect(Fmt.seats(1), '1 место');
    expect(Fmt.seats(3), '3 места');
    expect(Fmt.seats(11), '11 мест');
    expect(Fmt.seats(22), '22 места');
    expect(Fmt.price(0), 'Бесплатно');
    expect(Fmt.price(null), 'Цена уточняется');
    expect(Fmt.time(DateTime.utc(2026, 1, 1, 15, 30)), '18:30');
  });
}
