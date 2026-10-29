import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';

/// Members who may cancel a paid training at any time before it starts
/// (the usual rule is 24 hours). The cash part is refunded as ⛰️ as usual.
const Set<String> paidCancelAnytimeUsernames = <String>{
  '@Zhorenty',
};

final Set<String> _normalized =
    paidCancelAnytimeUsernames.map(normalizeTelegramUsername).whereType<String>().toSet();

bool isPaidCancelAnytime(String? username) {
  final normalized = normalizeTelegramUsername(username);
  return normalized != null && _normalized.contains(normalized);
}
