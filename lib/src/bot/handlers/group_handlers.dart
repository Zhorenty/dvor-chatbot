import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class GroupHandlers {
  GroupHandlers({
    required MessageSender sender,
    OnboardingRepository onboardingRepository = const NoopOnboardingRepository(),
    required MessageTemplates templates,
    required int? targetChatId,
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _onboardingRepository = onboardingRepository,
        _templates = templates,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final OnboardingRepository _onboardingRepository;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final DateTime Function() _nowProvider;

  Future<bool> handleUpdate(Map<String, dynamic> update) async {
    final message = update['message'];
    if (message is Map) {
      final handledMessage = await handleMessage(Map<String, dynamic>.from(message));
      if (handledMessage) {
        return true;
      }
    }

    final chatMember = update['chat_member'];
    if (chatMember is! Map) {
      return false;
    }

    return _handleChatMember(Map<String, dynamic>.from(chatMember));
  }

  Future<bool> handle(Map<String, dynamic> message) async {
    return handleMessage(message);
  }

  Future<bool> handleMessage(Map<String, dynamic> message) async {
    final chat = message['chat'];
    if (chat is! Map) {
      return false;
    }
    final chatType = chat['type']?.toString();
    if (chatType != 'group' && chatType != 'supergroup') {
      return false;
    }

    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    if (_targetChatId != null && _targetChatId != chatId) {
      return false;
    }

    final newMembers = message['new_chat_members'];
    if (newMembers is! List) {
      return false;
    }

    for (final item in newMembers.whereType<Map<Object?, Object?>>()) {
      final user = Map<String, dynamic>.from(item);
      await _welcomeUser(
        chatId: chatId,
        user: user,
        joinedAt: _extractJoinedAt(message) ?? _nowProvider(),
      );
    }

    return true;
  }

  Future<bool> _handleChatMember(Map<String, dynamic> chatMember) async {
    final chat = chatMember['chat'];
    if (chat is! Map) {
      return false;
    }
    final chatType = chat['type']?.toString();
    if (chatType != 'group' && chatType != 'supergroup') {
      return false;
    }

    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    if (_targetChatId != null && _targetChatId != chatId) {
      return false;
    }

    final oldChatMember = chatMember['old_chat_member'];
    final newChatMember = chatMember['new_chat_member'];
    if (oldChatMember is! Map || newChatMember is! Map) {
      return false;
    }

    final oldStatus = oldChatMember['status']?.toString();
    final newStatus = newChatMember['status']?.toString();
    final oldIsMember = oldChatMember['is_member'] == true;
    final newIsMember = newChatMember['is_member'] == true;
    if (!_isJoinTransition(
      oldStatus: oldStatus,
      newStatus: newStatus,
      oldIsMember: oldIsMember,
      newIsMember: newIsMember,
    )) {
      return false;
    }

    final user = newChatMember['user'];
    if (user is! Map) {
      return false;
    }

    await _welcomeUser(
      chatId: chatId,
      user: Map<String, dynamic>.from(user),
      joinedAt: _extractJoinedAt(chatMember) ?? _nowProvider(),
    );
    return true;
  }

  bool _isJoinTransition({
    required String? oldStatus,
    required String? newStatus,
    required bool oldIsMember,
    required bool newIsMember,
  }) {
    final wasMember = _isEffectiveMember(status: oldStatus, isMemberFlag: oldIsMember);
    final isMemberNow = _isEffectiveMember(status: newStatus, isMemberFlag: newIsMember);
    return !wasMember && isMemberNow;
  }

  bool _isEffectiveMember({
    required String? status,
    required bool isMemberFlag,
  }) {
    if (status == null) {
      return false;
    }
    switch (status) {
      case 'creator':
      case 'administrator':
      case 'member':
        return true;
      case 'restricted':
        return isMemberFlag;
      default:
        return false;
    }
  }

  Future<void> _welcomeUser({
    required int chatId,
    required Map<String, dynamic> user,
    required DateTime joinedAt,
  }) async {
    if (user['is_bot'] == true) {
      return;
    }
    final userId = user['id'];
    if (userId is! int) {
      return;
    }

    try {
      final welcomeMessageId = await _sender.sendMessage(
        chatId,
        _templates.groupWelcome(
          username: user['username']?.toString(),
          userId: userId,
          firstName: user['first_name']?.toString(),
        ),
        disableNotification: true,
        parseMode: 'HTML',
      );
      await _onboardingRepository.registerGroupWelcome(
        userId: userId,
        groupChatId: chatId,
        welcomeMessageId: welcomeMessageId,
        joinedAt: joinedAt,
      );
    } on Object catch (error) {
      l.w('Failed to process welcome for user $userId: $error');
    }
  }

  DateTime? _extractJoinedAt(Map<String, dynamic> message) {
    final rawDate = message['date'];
    if (rawDate is! int) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(rawDate * 1000, isUtc: true).toLocal();
  }
}
