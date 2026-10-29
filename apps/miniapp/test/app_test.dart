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
  final List<String> rpcCalls = <String>[];
  Map<String, Object?> Function(String method, Map<String, Object?> params)? onRpc;

  @override
  Future<Map<String, Object?>> rpc(String method, [Map<String, Object?> params = const {}]) async {
    rpcCalls.add(method);
    return onRpc?.call(method, params) ?? const <String, Object?>{};
  }

  _FakeRepository({this.isAdmin = false, this.userBookings = const []});

  final bool isAdmin;
  final List<Booking> userBookings;
  final List<String> booked = <String>[];
  final List<String> reviewed = <String>[];
  final List<String> marked = <String>[];
  ApiException? bookError;
  ApiException? markError;

  final List<AdminPayment> payments = [
    AdminPayment(
      id: 12,
      category: EventCategory.hikes,
      title: 'Поход выходного дня',
      startsAt: DateTime.utc(2026, 11, 7, 4),
      location: 'Маршрут',
      organizer: '@runner',
      prepayPercent: 50,
      total: 12000,
      partial: true,
      participants: const ['@runner', 'Гость'],
      comment: 'перевод с карты',
    ),
  ];

  final AdminSession _past = AdminSession(
    key: 'power',
    category: EventCategory.trainings,
    title: 'Силовая',
    startsAt: DateTime.utc(2026, 10, 27, 16),
    location: 'Зал',
    limit: 10,
    participants: 1,
    attendanceOpen: true,
    unmarked: 1,
  );

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
    ClubEvent(
      key: 'sons',
      category: EventCategory.trainings,
      title: 'Четыре сына',
      startsAt: DateTime.utc(2026, 11, 7, 5, 30),
      location: 'Набережная',
      price: 0,
      featured: true,
    ),
  ];

  @override
  Future<Me> me() async =>
      Me(id: 1, firstName: 'Аня', peaks: 120, botUsername: 'dvor_bot', isAdmin: isAdmin);

  @override
  Future<List<ClubEvent>> events() async => _events;

  @override
  Future<List<Booking>> bookings() async => userBookings;

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

  @override
  Future<List<AdminPayment>> adminPayments() async =>
      payments.where((p) => !reviewed.any((r) => r.startsWith('${p.id}:'))).toList();

  @override
  Future<void> reviewPayment(int bookingId, PaymentDecision decision) async =>
      reviewed.add('$bookingId:${decision.wire}');

  @override
  Future<void> sendProof(int bookingId) async {}

  @override
  Future<List<AdminSession>> adminSessions() async => [_past];

  @override
  Future<Roster> roster(String key) async => Roster(
    session: _past,
    participants: [
      AdminParticipant(
        bookingId: 31,
        name: '@runner',
        status: BookingStatus.paid,
        canMark: true,
        attendance: marked.isEmpty ? null : Attendance.attended,
      ),
    ],
  );

  @override
  Future<AdminParticipant> markAttendance(int bookingId, Attendance attendance) async {
    final error = markError;
    if (error != null) {
      throw error;
    }
    marked.add('$bookingId:${attendance.wire}');
    return AdminParticipant(
      bookingId: bookingId,
      name: '@runner',
      status: BookingStatus.paid,
      canMark: true,
      attendance: attendance,
    );
  }
}

Future<(_FakeRepository, StubTelegramPlatform)> _pump(
  WidgetTester tester, {
  bool isAdmin = false,
  List<Booking> bookings = const [],
}) async {
  await initializeDateFormatting('ru');
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = _FakeRepository(isAdmin: isAdmin, userBookings: bookings);
  final tg = StubTelegramPlatform();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        telegramProvider.overrideWithValue(tg),
        repositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: DvorApp(router: buildRouter(isAdmin: isAdmin)),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, tg);
}

void main() {
  testWidgets('schedule groups events by day and filters by category', (tester) async {
    await _pump(tester);
    expect(find.text('БОКС'), findsOneWidget);
    expect(find.text('ЗАВТРА · 29 ОКТЯБРЯ'), findsOneWidget);
    expect(find.text('Осталось 2 места'), findsOneWidget);
    expect(find.text('ВЫЕЗДЫ'), findsOneWidget);
    expect(find.text('ПОХОД ВЫХОДНОГО ДНЯ'), findsOneWidget);
    // The featured event sits on top, once, whatever the filter.
    expect(find.text('ГЛАВНОЕ'), findsOneWidget);
    expect(find.text('ЧЕТЫРЕ СЫНА'), findsOneWidget);

    await tester.tap(find.text('Походы'));
    await tester.pumpAndSettle();
    expect(find.text('БОКС'), findsNothing);
    expect(find.text('ПОХОД ВЫХОДНОГО ДНЯ'), findsOneWidget);
    expect(find.text('ЧЕТЫРЕ СЫНА'), findsOneWidget);
  });

  testWidgets('booking opens the in-app payment and sends the receipt step', (tester) async {
    final (repo, _) = await _pump(tester);
    repo.onRpc = (method, params) => switch (method) {
      'payment.options' => {
        'payable': true,
        'amount': 700,
        'participants': 1,
        'sbpLink': 'https://sbp.example',
        'peaks': {'balance': 0, 'available': false},
        'promo': true,
      },
      'payment.bonus' => {'message': 'Стартовая применена.'},
      _ => const <String, Object?>{},
    };
    await tester.tap(find.text('БОКС'));
    await tester.pumpAndSettle();
    expect(find.text('Записаться · 700 ₽'), findsOneWidget);

    await tester.tap(find.text('Записаться · 700 ₽'));
    await tester.pumpAndSettle();
    expect(repo.booked, ['box']);
    expect(find.text('МЕСТО ЗА ТОБОЙ'), findsOneWidget);

    await tester.tap(find.text('Перейти к оплате'));
    await tester.pumpAndSettle();
    expect(repo.rpcCalls, contains('payment.options'));
    expect(find.text('Прикрепить чек'), findsOneWidget);
    expect(find.text('Стартовая тренировка'), findsNothing);
  });

  testWidgets('opening bookings marks the unpaid notice as read', (tester) async {
    await _pump(
      tester,
      bookings: [
        Booking(
          id: 9,
          key: 'box',
          category: EventCategory.trainings,
          title: 'Бокс',
          startsAt: DateTime.utc(2026, 11, 1, 16),
          location: 'Зал',
          status: BookingStatus.pendingPayment,
        ),
      ],
    );
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('Ждёт оплаты'), findsWidgets);
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

  testWidgets('members never see admin tabs and admins never see member tabs', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
    expect(find.byIcon(Icons.receipt_long_rounded), findsNothing);
    expect(find.text('БОКС'), findsOneWidget);
  });

  testWidgets('admin approves a prepayment from the queue', (tester) async {
    final (repo, _) = await _pump(tester, isAdmin: true);
    expect(find.text('ОПЛАТЫ · 1'), findsOneWidget);
    expect(find.text('АФИША'), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.text('@runner, Гость'), findsOneWidget);
    expect(find.text('Предоплата 50%'), findsOneWidget);

    await tester.tap(find.text('Подтвердить предоплату'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Подтвердить'));
    await tester.pumpAndSettle();
    expect(repo.reviewed, ['12:approve_partial']);
    expect(find.text('Оплата #12 подтверждена'), findsOneWidget);
    expect(find.text('Очередь пуста'), findsOneWidget);
  });

  testWidgets('admin marks attendance on the roster', (tester) async {
    final (repo, _) = await _pump(tester, isAdmin: true);
    await tester.tap(find.byIcon(Icons.fact_check_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('без отметки: 1', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Силовая'));
    await tester.pumpAndSettle();
    expect(find.text('СИЛОВАЯ'), findsOneWidget);
    await tester.tap(find.text('Был'));
    await tester.pumpAndSettle();
    expect(repo.marked, ['31:attended']);

    repo.markError = const ApiException('not_allowed', 'Эту запись уже нельзя отметить.');
    await tester.tap(find.text('Не был'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Эту запись уже нельзя отметить.'), findsOneWidget);
  });

  test('admin models parse API payloads', () {
    final payment = AdminPayment.fromJson({
      'id': 4,
      'category': 'trainings',
      'title': 'Бокс',
      'startsAt': '2026-11-01T16:00:00.000Z',
      'location': 'Зал',
      'total': 700,
      'paymentType': 'full',
      'organizer': {'userId': 9, 'name': 'id 9'},
      'participants': <Object?>[],
      'hasProof': true,
    });
    expect(payment.partial, isFalse);
    expect(payment.organizer, 'id 9');
    expect(payment.hasProof, isTrue);

    final participant = AdminParticipant.fromJson({
      'bookingId': 5,
      'name': 'Гость',
      'guest': true,
      'status': 'partial_paid',
      'attendance': 'absent',
      'canMark': true,
    });
    expect(participant.status, BookingStatus.partialPaid);
    expect(participant.attendance, Attendance.absent);
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
    expect(event.isPinned, isFalse);

    final sons = ClubEvent.fromJson({
      'key': 'sons',
      'title': '🍕 DVOR x Четыре сына',
      'startsAt': '2026-11-07T05:30:00.000Z',
      'featured': true,
    });
    expect(sons.isPinned, isTrue);
    expect(sons.featured, isTrue);

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

  test('leading emoji moves out of the title', () {
    expect(splitTitleEmoji('🥊 BOXING DVOR'), (emoji: '🥊', text: 'BOXING DVOR'));
    expect(splitTitleEmoji('🏃 MORNING RUN с Антоном'), (
      emoji: '🏃',
      text: 'MORNING RUN с Антоном',
    ));
    expect(splitTitleEmoji('DVOR X ЧЕТЫРЕ СЫНА'), (emoji: null, text: 'DVOR X ЧЕТЫРЕ СЫНА'));
    expect(splitTitleEmoji('«Кэмп»'), (emoji: null, text: '«Кэмп»'));
    expect(sameTelegramNick('@Runner', 'runner'), isTrue);
    expect(sameTelegramNick('Runner', '@runner'), isTrue);
    expect(sameTelegramNick('alice', 'bob'), isFalse);
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
