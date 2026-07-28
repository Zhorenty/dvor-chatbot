import 'package:dvor_chatbot/src/bot/handlers/private/admin_gate.dart';
import 'package:test/test.dart';

void main() {
  test('AdminGate recognizes configured admins only', () {
    const gate = AdminGate({10, 20});
    expect(gate.isConfiguredAdmin(10), isTrue);
    expect(gate.isConfiguredAdmin(99), isFalse);
    expect(gate.isConfiguredAdmin(null), isFalse);
    expect(gate.canRunAdminAction(isConfiguredAdmin: true), isTrue);
    expect(gate.canRunAdminAction(isConfiguredAdmin: false), isFalse);
  });
}
