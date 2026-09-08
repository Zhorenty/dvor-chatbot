const Set<int> trainerBookingWhitelistUserIds = <int>{};

const Set<String> trainerBookingWhitelistUsernames = <String>{
  /// Босс
  '@Zhorenty',

  /// Денчик
  '@nudden',
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

String? telegramUsernameFromLink(String? rawLink) {
  final trimmed = rawLink?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('@')) {
    return normalizeTelegramUsername(trimmed);
  }
  final withScheme = (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
      ? trimmed
      : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  final host = uri?.host.toLowerCase();
  if (uri != null &&
      (host == 't.me' ||
          host == 'www.t.me' ||
          host == 'telegram.me' ||
          host == 'www.telegram.me')) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return normalizeTelegramUsername(segment);
  }
  return normalizeTelegramUsername(trimmed);
}
