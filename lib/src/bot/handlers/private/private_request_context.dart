import 'package:dvor_chatbot/src/bot/handlers/private/private_context.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';

/// Per-update request state for private dispatch handlers.
final class PrivateRequestContext {
  const PrivateRequestContext({
    required this.chatId,
    required this.userId,
    required this.text,
    required this.isAdmin,
    required this.isConfiguredAdmin,
    required this.showReturnToAdminMenu,
    required this.canRunAdminAction,
    required this.canRunParticipantsAction,
    required this.isWhitelistedTrainer,
    required this.flowState,
    required this.paymentProof,
    required this.username,
    required this.message,
    this.callbackMessage,
  });

  final int chatId;
  final int? userId;
  final String? text;
  final bool isAdmin;
  final bool isConfiguredAdmin;
  final bool showReturnToAdminMenu;
  final bool canRunAdminAction;
  final bool canRunParticipantsAction;
  final bool isWhitelistedTrainer;
  final PrivateFlowState? flowState;
  final PaymentProof? paymentProof;
  final String? username;
  final Map<String, dynamic>? message;
  final Map<String, dynamic>? callbackMessage;
}
