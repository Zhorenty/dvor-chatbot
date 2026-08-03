import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';

final class PrivateMessageContext {
  const PrivateMessageContext({
    required this.chat,
    required this.from,
    required this.text,
    required this.message,
    required this.callbackQueryId,
    this.callbackMessage,
  });

  final Map<String, dynamic> chat;
  final Map<String, dynamic>? from;
  final String? text;
  final Map<String, dynamic>? message;
  final String? callbackQueryId;

  /// Source message of a callback query (for editMessageReplyMarkup).
  final Map<String, dynamic>? callbackMessage;
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
      callbackMessage: callbackMessage,
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
  final messageId = _asTelegramInt(message['message_id']);
  final chatRaw = message['chat'];
  if (messageId == null || chatRaw is! Map) {
    return null;
  }
  final chat = Map<String, dynamic>.from(chatRaw);
  final fromChatId = _asTelegramInt(chat['id']);
  if (fromChatId == null) {
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

int? _asTelegramInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

/// Extracts a photo message suitable for admin broadcast (photo only, not documents).
({int fromChatId, int messageId, String? mediaGroupId})? extractBroadcastPhoto(
  Map<String, dynamic>? message,
) {
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
  final hasPhoto = message['photo'] is List && (message['photo'] as List).isNotEmpty;
  if (!hasPhoto) {
    return null;
  }
  final mediaGroupId = message['media_group_id']?.toString();
  return (
    fromChatId: fromChatId,
    messageId: messageId,
    mediaGroupId: mediaGroupId == null || mediaGroupId.isEmpty ? null : mediaGroupId,
  );
}

String? callbackToCommandText(String? callbackData) {
  if (callbackData == null) {
    return null;
  }
  if (callbackData.startsWith(MessageCopy.callbackApprovePaymentPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackApprovePaymentPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/approve_payment $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackApprovePartialPaymentPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackApprovePartialPaymentPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/approve_partial_payment $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackRejectPaymentPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackRejectPaymentPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/reject_payment $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackPayBookingPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackPayBookingPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/paid $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackPayFullPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackPayFullPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/paid_full $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackPayPartialPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackPayPartialPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/paid_partial $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackUseBonusPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackUseBonusPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/use_bonus $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackEnterPromoPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackEnterPromoPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/enter_promo $bookingId';
  }
  if (callbackData == MessageCopy.callbackOpenPaymentsQueue) {
    return '/payments_queue';
  }
  if (callbackData.startsWith(MessageCopy.callbackNextPaymentInQueuePrefix)) {
    final categoryKey =
        callbackData.substring(MessageCopy.callbackNextPaymentInQueuePrefix.length).trim();
    return '/payments_queue_next $categoryKey';
  }
  if (callbackData.startsWith(MessageCopy.callbackApproveSubscriptionPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackApproveSubscriptionPrefix.length);
    final requestId = int.tryParse(rawId);
    return requestId == null ? null : '/approve_subscription $requestId';
  }
  if (callbackData.startsWith(MessageCopy.callbackRejectSubscriptionPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackRejectSubscriptionPrefix.length);
    final requestId = int.tryParse(rawId);
    return requestId == null ? null : '/reject_subscription $requestId';
  }
  if (callbackData.startsWith(MessageCopy.callbackCancelSubscriptionPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackCancelSubscriptionPrefix.length);
    final requestId = int.tryParse(rawId);
    return requestId == null ? null : '/cancel_subscription $requestId';
  }
  if (callbackData == MessageCopy.callbackBroadcastToUsers) {
    return '/broadcast_users';
  }
  if (callbackData == MessageCopy.callbackBroadcastToGroup) {
    return '/broadcast_group';
  }
  if (callbackData == MessageCopy.callbackBroadcastToUsersAndGroup) {
    return '/broadcast_users_and_group';
  }
  if (callbackData == MessageCopy.callbackBroadcastCancel) {
    return '/broadcast_cancel';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingCancelConfirmPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingCancelConfirmPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/cancel_booking_confirm $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingCancelKeepPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingCancelKeepPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/cancel_booking_keep $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingCancelPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingCancelPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/cancel_booking $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingReschedulePrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingReschedulePrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/reschedule_booking $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingRepeatPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingRepeatPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/repeat_booking $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackBookingContinuePayPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackBookingContinuePayPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/paid $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackFeedbackSkipPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackFeedbackSkipPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/feedback_skip $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackFeedbackRatePrefix)) {
    final rest = callbackData.substring(MessageCopy.callbackFeedbackRatePrefix.length);
    final parts = rest.split(':');
    if (parts.length != 2) {
      return null;
    }
    final bookingId = int.tryParse(parts[0]);
    final rating = parts[1].trim();
    if (bookingId == null || rating.isEmpty) {
      return null;
    }
    return '/feedback_rate $bookingId $rating';
  }
  if (callbackData == MessageCopy.callbackCtaBook) {
    return MessageCopy.buttonBookTraining;
  }
  if (callbackData.startsWith(MessageCopy.callbackAdminBookingEditPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackAdminBookingEditPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/admin_booking_edit $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackAdminBookingDeleteConfirmPrefix)) {
    final rawId =
        callbackData.substring(MessageCopy.callbackAdminBookingDeleteConfirmPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/admin_booking_delete_confirm $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackAdminBookingDeleteAbortPrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackAdminBookingDeleteAbortPrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/admin_booking_delete_abort $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackAdminBookingDeletePrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackAdminBookingDeletePrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/admin_booking_delete $bookingId';
  }
  if (callbackData.startsWith(MessageCopy.callbackAdminBookingRestorePrefix)) {
    final rawId = callbackData.substring(MessageCopy.callbackAdminBookingRestorePrefix.length);
    final bookingId = int.tryParse(rawId);
    return bookingId == null ? null : '/admin_booking_restore $bookingId';
  }
  if (callbackData == MessageCopy.callbackAdminNotifyYes) {
    return MessageCopy.buttonNotifyClientYes;
  }
  if (callbackData == MessageCopy.callbackAdminNotifyNo) {
    return MessageCopy.buttonNotifyClientNo;
  }
  return null;
}
