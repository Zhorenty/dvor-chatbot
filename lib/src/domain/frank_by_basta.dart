import 'package:dvor_chatbot/src/domain/training_info.dart';

/// Helpers for the DVOR × FRANK BY BASTA special event.
///
/// Bookings must resolve the live schedule row so `sessionKey` matches
/// `✍️ Записаться` / admin participants for `🔴 DVORSPORT | FRANK BY BASTA`.
abstract final class FrankByBasta {
  static bool matchesTitle(String title) {
    final normalized = title.toUpperCase();
    return normalized.contains('FRANK') &&
        (normalized.contains('BASTA') || normalized.contains('БАСТА'));
  }

  static TrainingInfo? findIn(Iterable<TrainingInfo> items) {
    final matches = items.where((item) => matchesTitle(item.title)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return matches.isEmpty ? null : matches.first;
  }
}
