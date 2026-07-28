import 'package:dvor_chatbot/src/bot/handlers/private/admin_gate.dart';

/// Thin admin policy helper used by [PrivateHandlers].
final class AdminHandler {
  const AdminHandler({AdminGate? gate}) : _gate = gate;

  final AdminGate? _gate;

  bool canRunAdminAction({required bool isAdmin}) {
    final gate = _gate;
    if (gate != null) {
      return gate.canRunAdminAction(isConfiguredAdmin: isAdmin);
    }
    return isAdmin;
  }
}
