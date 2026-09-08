import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:test/test.dart';

void main() {
  group('telegramUsernameFromLink', () {
    test('parses @username, bare username and t.me links', () {
      expect(telegramUsernameFromLink('@Alex'), 'alex');
      expect(telegramUsernameFromLink('maria_run'), 'maria_run');
      expect(telegramUsernameFromLink('https://t.me/maria_run'), 'maria_run');
      expect(telegramUsernameFromLink('t.me/@alex'), 'alex');
      expect(telegramUsernameFromLink('https://t.me/@alex'), 'alex');
      expect(telegramUsernameFromLink(''), isNull);
      expect(telegramUsernameFromLink(null), isNull);
    });
  });
}
