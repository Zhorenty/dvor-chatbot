import 'package:dvor_chatbot/src/messages/message_templates.dart';

final class PrivateMessageContext {
  const PrivateMessageContext({
    required this.chat,
    required this.from,
    required this.text,
    required this.message,
    required this.callbackQueryId,
  });

  final Map<String, dynamic> chat;
  final Map<String, dynamic>? from;
  final String? text;
  final Map<String, dynamic>? message;
  final String? callbackQueryId;
}

final class PaymentProof {
  const PaymentProof({
    required this.fromChatId,
    required this.messageId,
    required this.caption,
  });

  final int fromChatId;
  final int messageId;
  final String? caption;
}

PrivateMessageContext? extractPrivateMessageContext(Map<String, dynamic> update) {
  final callback = update['callback_query'];
  if (callback is Map) {
    final callbackMap = Map<String, dynamic>.from(callback);
    final callbackMessageRaw = callbackMap['message'];
    final fromRaw = callbackMap['from'];
    final text = callbackToCommandText(callbackMap['data']?.toString());
    if (callbackMessageRaw is! Map || text == null) {
      return null;
    }
    final callbackMessage = Map<String, dynamic>.from(callbackMessageRaw);
    final callbackChatRaw = callbackMessage['chat'];
    if (callbackChatRaw is! Map) {
      return null;
    }
    return PrivateMessageContext(
      chat: Map<String, dynamic>.from(callbackChatRaw),
      from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
      text: text,
      message: null,
      callbackQueryId: callbackMap['id']?.toString(),
    );
  }

  final messageRaw = update['message'];
  if (messageRaw is Map) {
    final message = Map<String, dynamic>.from(messageRaw);
    final chatRaw = message['chat'];
    if (chatRaw is! Map) {
      return null;
    }
    final fromRaw = message['from'];
    return PrivateMessageContext(
      chat: Map<String, dynamic>.from(chatRaw),
      from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
      text: message['text']?.toString().trim(),
      message: message,
      callbackQueryId: null,
    );
  }

  final chatRaw = update['chat'];
  if (chatRaw is! Map) {
    return null;
  }
  final fromRaw = update['from'];
  return PrivateMessageContext(
    chat: Map<String, dynamic>.from(chatRaw),
    from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
    text: update['text']?.toString().trim(),
    message: update,
    callbackQueryId: null,
  );
}

PaymentProof? extractPaymentProof(Map<String, dynamic>? message) {
  if (message == null) {
    return null;
  }
  final messageId = message['message_id'];
  final chatRaw = message['chat'];
  if (messageId is! int || chatRaw is! Map) {
    return null;
  }
  final chat = Map<String, dynamic>.from(chatRaw);
  final fromChatId = chat['id'];
  if (fromChatId is! int) {
    return null;
  }
  final hasDocument = message['document'] is Map;
  final hasPhoto = message['photo'] is List && (message['photo'] as List).isNotEmpty;
  if (!hasDocument && !hasPhoto) {
    return null;
  }
  return PaymentProof(
    fromChatId: fromChatId,
    messageId: messageId,
    caption: message['caption']?.toString().trim(),
  );
}

String? callbackToCommandText(String? callbackData) {
  if (callbackData == null) {
    return null;
  }
  if (callbackData.startsWith(MessageTemplates.callbackApprovePaymentPrefix)) {
    final rawId = callbackData.substring(MessageTemplates.callbackApprovePaymentPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/approve_payment $bookingId';
  }
  if (callbackData.startsWith(MessageTemplates.callbackRejectPaymentPrefix)) {
    final rawId = callbackData.substring(MessageTemplates.callbackRejectPaymentPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/reject_payment $bookingId';
  }
  if (callbackData == MessageTemplates.callbackOpenPaymentsQueue) {
    return '/payments_queue';
  }
  return null;
}
