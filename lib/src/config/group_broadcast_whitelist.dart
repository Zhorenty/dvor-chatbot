import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';

/// Client usernames that may open a limited admin menu and send broadcasts
/// to the club group only (not DMs to all started users).
const Set<String> groupBroadcastWhitelistUsernames = <String>{
  '@mathkhart',
};

final Set<String> _normalizedGroupBroadcastWhitelistUsernames =
    groupBroadcastWhitelistUsernames.map(normalizeTelegramUsername).whereType<String>().toSet();

bool isGroupBroadcastWhitelisted({String? username}) {
  final normalized = normalizeTelegramUsername(username);
  return normalized != null && _normalizedGroupBroadcastWhitelistUsernames.contains(normalized);
}
