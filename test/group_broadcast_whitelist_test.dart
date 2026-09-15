import 'package:dvor_chatbot/src/config/group_broadcast_whitelist.dart';
import 'package:test/test.dart';

void main() {
  group('isGroupBroadcastWhitelisted', () {
    test('matches @mathkhart regardless of case and leading @', () {
      expect(isGroupBroadcastWhitelisted(username: 'mathkhart'), isTrue);
      expect(isGroupBroadcastWhitelisted(username: '@MathKHart'), isTrue);
      expect(isGroupBroadcastWhitelisted(username: 'Mathkhart'), isTrue);
    });

    test('rejects other usernames and empty values', () {
      expect(isGroupBroadcastWhitelisted(username: 'nudden'), isFalse);
      expect(isGroupBroadcastWhitelisted(username: null), isFalse);
      expect(isGroupBroadcastWhitelisted(username: ''), isFalse);
    });
  });
}
