/// Detects bot DMs sent for вершинки credits / expiry, so a quiet remigration
/// can delete them without touching spend, help, or profile texts.
abstract final class LoyaltyCreditDm {
  static const List<String> _creditReasons = <String>[
    'за поход',
    'за тренировку',
    'за трейл',
    'за старт',
    'за первый старт',
    'за приглашение',
    'за бокс-карту',
    'за отзыв',
    'перенос',
    'начисление',
    'возврат',
  ];

  static bool matches(String? text) {
    if (text == null || text.isEmpty) {
      return false;
    }
    final trimmed = text.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.contains('⛰️ сгорят')) {
      return true;
    }
    if (trimmed.contains('Сгорели ') && trimmed.contains('⛰️')) {
      return true;
    }
    if (!trimmed.contains('+') || !trimmed.contains('⛰️')) {
      return false;
    }
    for (final reason in _creditReasons) {
      if (trimmed.contains(reason)) {
        return true;
      }
    }
    return false;
  }
}
