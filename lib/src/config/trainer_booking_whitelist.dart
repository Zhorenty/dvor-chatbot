const Set<int> trainerBookingWhitelistUserIds = <int>{};

const Set<String> trainerBookingWhitelistUsernames = <String>{
  /// Жора
  '@zhorenty',

  /// Катя
  '@k_morozzovaa',

  /// Света
  '@pro_svet_lena',

  /// Даша
  '@whatshapped',

  /// Андрей
  '@androdentio',

  /// Денис
  '@nudden',

  /// Саша Шум
  '@shum_show',

  /// Антон
  '@dukarev_team',

  /// Паша
  '@benjaminnnnnm',

  /// Родя
  '@oh_rodya',
};

final Set<String> _normalizedTrainerBookingWhitelistUsernames =
    trainerBookingWhitelistUsernames.map(normalizeTelegramUsername).whereType<String>().toSet();

bool isTrainerBookingWhitelisted({
  required int userId,
  String? username,
}) {
  if (trainerBookingWhitelistUserIds.contains(userId)) {
    return true;
  }
  final normalized = normalizeTelegramUsername(username);
  return normalized != null && _normalizedTrainerBookingWhitelistUsernames.contains(normalized);
}

String? normalizeTelegramUsername(String? username) {
  final trimmed = username?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final raw = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  if (raw.isEmpty) {
    return null;
  }
  return raw.toLowerCase();
}
