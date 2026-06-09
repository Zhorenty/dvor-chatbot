import 'package:dvor_chatbot/src/bot/handlers/private/private_update_router.dart';
import 'package:test/test.dart';

void main() {
  group('PrivateUpdateRouter', () {
    const router = PrivateUpdateRouter();

    test('parses command id from command text', () {
      expect(router.parseCommandId('/approve_payment 42'), 42);
      expect(router.parseCommandId('/approve_payment'), isNull);
    });

    test('parses training selection index from different formats', () {
      expect(router.parseTrainingSelectionIndex('2'), 2);
      expect(router.parseTrainingSelectionIndex('🎯 3. Evening run'), 3);
      expect(router.parseTrainingSelectionIndex('4. Morning session'), 4);
      expect(router.parseTrainingSelectionIndex('no index'), isNull);
    });

    test('parses booking id from list selection line', () {
      expect(router.parseBookingIdSelection('#129 • user'), 129);
      expect(router.parseBookingIdSelection('no id'), isNull);
    });
  });
}
