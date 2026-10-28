import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/repository.dart';

/// Local preview data (`--dart-define=DVOR_DEMO=true`). Never used in
/// production builds: outside Telegram the app asks to open it from the bot.
class DemoRepository implements DvorRepository {
  DemoRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<Booking> _bookings = <Booking>[];
  int _nextId = 1;

  DateTime _at(int dayOffset, int hourMsk, [int minute = 0]) {
    final today = _now().toUtc().add(const Duration(hours: 3));
    return DateTime.utc(today.year, today.month, today.day + dayOffset, hourMsk - 3, minute);
  }

  late final List<ClubEvent> _events = <ClubEvent>[
    ClubEvent(
      key: 'demo-run',
      category: EventCategory.trainings,
      title: 'Утренний забег',
      startsAt: _at(1, 8),
      location: 'Демо-площадка',
      price: 0,
      limit: 20,
      taken: 12,
      coach: 'Демо-тренер',
    ),
    ClubEvent(
      key: 'demo-box',
      category: EventCategory.trainings,
      title: 'Бокс',
      startsAt: _at(1, 19, 30),
      location: 'Демо-зал',
      price: 700,
      limit: 12,
      taken: 10,
      coach: 'Демо-тренер',
      notes: 'Бинты и капа — с собой.',
    ),
    ClubEvent(
      key: 'demo-strength',
      category: EventCategory.trainings,
      title: 'Силовая',
      startsAt: _at(2, 19),
      location: 'Демо-зал',
      price: 600,
      limit: 14,
      taken: 14,
    ),
    ClubEvent(
      key: 'demo-hike',
      category: EventCategory.hikes,
      title: 'Поход выходного дня',
      startsAt: _at(5, 7),
      endsAt: _at(6, 19),
      location: 'Демо-маршрут',
      price: 6500,
      prepayPercent: 50,
      limit: 16,
      taken: 9,
      description: 'Демо-описание маршрута: два дня, ночёвка в палатках.',
      equipment: 'Рюкзак, спальник, треккинговая обувь.',
    ),
    ClubEvent(
      key: 'demo-trail',
      category: EventCategory.trails,
      title: 'Трейл',
      startsAt: _at(9, 9),
      location: 'Демо-трейл',
      price: 2500,
      prepayPercent: 50,
      limit: 25,
      taken: 3,
      description: 'Демо-описание трейла.',
    ),
  ];

  @override
  Future<Me> me() async {
    await _delay();
    return Me(
      id: 1,
      firstName: 'Гость',
      username: 'demo',
      peaks: 340,
      visits: 7,
      invited: 1,
      bookings: _bookings.where((b) => b.status.isActive).length,
      botUsername: 'dvor_demo_bot',
      referralLink: 'https://t.me/dvor_demo_bot?start=ref_1',
    );
  }

  @override
  Future<List<ClubEvent>> events() async {
    await _delay();
    return _events;
  }

  @override
  Future<List<Booking>> bookings() async {
    await _delay();
    return List<Booking>.unmodifiable(_bookings);
  }

  @override
  Future<ActionResult> book(String key) async {
    await _delay(700);
    final event = _events.firstWhere((e) => e.key == key);
    if (event.isFull) {
      throw const ApiException('full', 'Мест уже нет.');
    }
    final existing = _bookings.where((b) => b.key == key && b.status.isActive);
    if (existing.isNotEmpty) {
      return ActionResult(outcome: ActionOutcome.exists, booking: existing.first);
    }
    final booking = Booking(
      id: _nextId++,
      key: key,
      category: event.category,
      title: event.title,
      startsAt: event.startsAt,
      location: event.location,
      status: event.isFree ? BookingStatus.paid : BookingStatus.pendingPayment,
      price: event.price,
      prepayPercent: event.prepayPercent,
      canCancel: true,
    );
    _bookings.add(booking);
    return ActionResult(outcome: ActionOutcome.created, booking: booking);
  }

  @override
  Future<ActionResult> cancel(int bookingId) async {
    await _delay(500);
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    final b = _bookings[index];
    final cancelled = Booking(
      id: b.id,
      key: b.key,
      category: b.category,
      title: b.title,
      startsAt: b.startsAt,
      location: b.location,
      status: BookingStatus.cancelled,
      price: b.price,
    );
    _bookings[index] = cancelled;
    return ActionResult(outcome: ActionOutcome.cancelled, booking: cancelled);
  }

  Future<void> _delay([int ms = 350]) => Future<void>.delayed(Duration(milliseconds: ms));
}
