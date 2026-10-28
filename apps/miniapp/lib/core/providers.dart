import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/repository.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in main() with the real platform and repository.
final telegramProvider = Provider<TelegramPlatform>((ref) => throw UnimplementedError());

final repositoryProvider = Provider<DvorRepository>((ref) => throw UnimplementedError());

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final meProvider = FutureProvider<Me>((ref) => ref.watch(repositoryProvider).me());

final eventsProvider = FutureProvider<List<ClubEvent>>((ref) {
  return ref.watch(repositoryProvider).events();
});

final bookingsProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(repositoryProvider).bookings();
});

/// Active bookings by event key, for "ты записан" badges.
final bookedKeysProvider = Provider<Map<String, Booking>>((ref) {
  final bookings = ref.watch(bookingsProvider).value ?? const <Booking>[];
  return {
    for (final b in bookings)
      if (b.status.isActive && b.participant == null) b.key: b,
  };
});

class CategoryFilter extends Notifier<EventCategory?> {
  @override
  EventCategory? build() => null;

  void select(EventCategory? category) => state = category;
}

final categoryFilterProvider = NotifierProvider<CategoryFilter, EventCategory?>(CategoryFilter.new);

/// Booking and cancellation with cache refresh.
class BookingActions {
  BookingActions(this._ref);

  final Ref _ref;

  Future<ActionResult> book(String key) async {
    try {
      return await _ref.read(repositoryProvider).book(key);
    } finally {
      _refresh();
    }
  }

  Future<ActionResult> cancel(int bookingId) async {
    try {
      return await _ref.read(repositoryProvider).cancel(bookingId);
    } finally {
      _refresh();
    }
  }

  void _refresh() {
    _ref
      ..invalidate(bookingsProvider)
      ..invalidate(eventsProvider)
      ..invalidate(meProvider);
  }
}

final bookingActionsProvider = Provider<BookingActions>(BookingActions.new);
