import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/repository.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in main() with the real platform and repository.
final telegramProvider = Provider<TelegramPlatform>((ref) => throw UnimplementedError());

final repositoryProvider = Provider<DvorRepository>((ref) => throw UnimplementedError());

/// Safe-area insets; rebuilds only widgets that read them, only on change.
final safeAreaProvider = Provider<EdgeInsets>((ref) {
  final listenable = ref.watch(telegramProvider).safeAreaListenable;
  void onChange() => ref.invalidateSelf();
  listenable.addListener(onChange);
  ref.onDispose(() => listenable.removeListener(onChange));
  return listenable.value;
});

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

final adminPaymentsProvider = FutureProvider<List<AdminPayment>>((ref) {
  return ref.watch(repositoryProvider).adminPayments();
});

final adminSessionsProvider = FutureProvider<List<AdminSession>>((ref) {
  return ref.watch(repositoryProvider).adminSessions();
});

final rosterProvider = FutureProvider.family<Roster, String>((ref, key) {
  return ref.watch(repositoryProvider).roster(key);
});

/// Admin writes with cache refresh. Notices to users go from the bot.
class AdminActions {
  AdminActions(this._ref);

  final Ref _ref;

  Future<void> review(int bookingId, PaymentDecision decision) async {
    try {
      await _ref.read(repositoryProvider).reviewPayment(bookingId, decision);
    } finally {
      _ref
        ..invalidate(adminPaymentsProvider)
        ..invalidate(adminSessionsProvider)
        ..invalidate(eventsProvider);
    }
  }

  Future<void> sendProof(int bookingId) => _ref.read(repositoryProvider).sendProof(bookingId);

  Future<AdminParticipant> mark(String key, int bookingId, Attendance attendance) async {
    try {
      return await _ref.read(repositoryProvider).markAttendance(bookingId, attendance);
    } finally {
      _ref
        ..invalidate(rosterProvider(key))
        ..invalidate(adminSessionsProvider);
    }
  }
}

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);

final paymentOptionsProvider = FutureProvider.autoDispose.family<PaymentOptions, int>((
  ref,
  id,
) async {
  return PaymentOptions.fromJson(
    await ref.watch(repositoryProvider).rpc('payment.options', {'bookingId': id}),
  );
});

final cardOverviewProvider = FutureProvider.autoDispose<CardOverview>((ref) async {
  return CardOverview.fromJson(await ref.watch(repositoryProvider).rpc('card.overview'));
});

final teamProvider = FutureProvider<List<TeamPerson>>((ref) async {
  final json = await ref.watch(repositoryProvider).rpc('team.list');
  return parseList(json['people'], TeamPerson.fromJson);
});

final adminCardRequestsProvider = FutureProvider<List<CardRequest>>((ref) async {
  final json = await ref.watch(repositoryProvider).rpc('admin.cards.pending');
  return parseList(json['requests'], CardRequest.fromJson);
});

final adminCatalogProvider = FutureProvider.autoDispose.family<List<CatalogItem>, EventCategory>((
  ref,
  category,
) async {
  final json = await ref.watch(repositoryProvider).rpc('admin.schedule.list', {
    'category': category.name,
  });
  return parseList(json['items'], CatalogItem.fromJson)
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
});

final adminBookingsProvider = FutureProvider.autoDispose
    .family<List<AdminBooking>, (EventCategory, bool)>((ref, args) async {
      final (category, archived) = args;
      final json = await ref.watch(repositoryProvider).rpc('admin.bookings.list', {
        'category': category.name,
        'archived': archived,
      });
      return parseList(json['bookings'], AdminBooking.fromJson);
    });

/// Calls a bot action and refreshes everything a write may touch.
class Rpc {
  Rpc(this._ref);

  final Ref _ref;

  Future<Map<String, Object?>> call(String method, [Map<String, Object?> params = const {}]) async {
    try {
      return await _ref.read(repositoryProvider).rpc(method, params);
    } finally {
      _ref
        ..invalidate(bookingsProvider)
        ..invalidate(eventsProvider)
        ..invalidate(meProvider)
        ..invalidate(paymentOptionsProvider)
        ..invalidate(cardOverviewProvider);
      if (method.startsWith('admin.')) {
        _ref
          ..invalidate(adminPaymentsProvider)
          ..invalidate(adminCardRequestsProvider)
          ..invalidate(adminSessionsProvider)
          ..invalidate(adminCatalogProvider)
          ..invalidate(adminBookingsProvider);
      }
    }
  }
}

final rpcProvider = Provider<Rpc>(Rpc.new);
