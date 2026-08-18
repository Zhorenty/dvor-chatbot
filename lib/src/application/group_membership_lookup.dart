import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';

abstract interface class GroupMembershipLookup {
  Future<bool> isChatMember({
    required int chatId,
    required int userId,
  });
}

final class TelegramGroupMembershipLookup implements GroupMembershipLookup {
  const TelegramGroupMembershipLookup(this._client);

  final TelegramClient _client;

  @override
  Future<bool> isChatMember({
    required int chatId,
    required int userId,
  }) async {
    try {
      final member = await _client.getChatMember(chatId: chatId, userId: userId);
      return isEffectiveGroupMember(
        status: member['status']?.toString(),
        isMemberFlag: member['is_member'] == true,
      );
    } on TelegramApiException catch (error) {
      if (_isAbsentMemberError(error.message)) {
        return false;
      }
      rethrow;
    }
  }

  bool _isAbsentMemberError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('user not found') ||
        lower.contains('participant_id_invalid') ||
        lower.contains('user is deactivated') ||
        lower.contains('user_id_invalid');
  }
}
