import 'package:dvor_chatbot/src/application/group_spam_detector.dart';
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
    Set<int> adminUserIds = const <int>{},
    int? adminChatId,
    bool antiSpamEnabled = true,
    GroupSpamDetector spamDetector = const GroupSpamDetector(),
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _onboardingRepository = onboardingRepository,
        _templates = templates,
        _targetChatId = targetChatId,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _antiSpamEnabled = antiSpamEnabled,
        _spamDetector = spamDetector,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final OnboardingRepository _onboardingRepository;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final bool _antiSpamEnabled;
  final GroupSpamDetector _spamDetector;
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

    if (_antiSpamEnabled && await _tryHandleSpam(chatId: chatId, message: message)) {
      return true;
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

  Future<bool> _tryHandleSpam({
    required int chatId,
    required Map<String, dynamic> message,
  }) async {
    if (_isServiceMessage(message)) {
      return false;
    }

    final from = message['from'];
    if (from is! Map) {
      return false;
    }
    if (from['is_bot'] == true) {
      return false;
    }

    final userId = from['id'];
    if (userId is! int) {
      return false;
    }
    if (_adminUserIds.contains(userId)) {
      return false;
    }

    final text = _extractMessageText(message);
    final detection = _spamDetector.evaluate(text);
    if (!detection.isSpam) {
      return false;
    }

    final messageId = message['message_id'];
    if (messageId is! int) {
      return false;
    }

    l.w(
      'Anti-spam hit: chatId=$chatId userId=$userId '
      'score=${detection.score} reasons=${detection.reasons.join(",")}',
    );

    try {
      await _sender.deleteMessage(chatId, messageId: messageId);
    } on Object catch (error) {
      l.w('Failed to delete spam message $messageId in chat $chatId: $error');
    }

    try {
      await _sender.banChatMember(chatId, userId: userId, revokeMessages: true);
    } on Object catch (error) {
      l.w('Failed to ban spam user $userId in chat $chatId: $error');
    }

    await _notifyAdminsAboutSpam(
      chatId: chatId,
      userId: userId,
      username: from['username']?.toString(),
      firstName: from['first_name']?.toString(),
      detection: detection,
      sampleText: text,
    );
    return true;
  }

  Future<void> _notifyAdminsAboutSpam({
    required int chatId,
    required int userId,
    required String? username,
    required String? firstName,
    required SpamDetectionResult detection,
    required String? sampleText,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }

    final who = username != null && username.isNotEmpty
        ? '@$username'
        : (firstName != null && firstName.isNotEmpty ? firstName : 'id:$userId');
    final preview = (sampleText ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final clipped = preview.length > 180 ? '${preview.substring(0, 180)}…' : preview;
    final text = StringBuffer()
      ..writeln('🛡 Антиспам: сообщение удалено, пользователь забанен.')
      ..writeln('Чат: $chatId')
      ..writeln('Кто: $who ($userId)')
      ..writeln('Причины: ${detection.reasons.join(', ')} (score=${detection.score})');
    if (clipped.isNotEmpty) {
      text.writeln('Текст: $clipped');
    }

    try {
      await _sender.sendMessage(
        adminChatId,
        text.toString().trimRight(),
        disableNotification: true,
      );
    } on Object catch (error) {
      l.w('Failed to notify admins about spam from $userId: $error');
    }
  }

  bool _isServiceMessage(Map<String, dynamic> message) {
    const serviceKeys = <String>{
      'new_chat_members',
      'left_chat_member',
      'new_chat_title',
      'new_chat_photo',
      'delete_chat_photo',
      'group_chat_created',
      'supergroup_chat_created',
      'channel_chat_created',
      'message_auto_delete_timer_changed',
      'migrate_to_chat_id',
      'migrate_from_chat_id',
      'pinned_message',
      'forum_topic_created',
      'forum_topic_closed',
      'forum_topic_reopened',
      'forum_topic_edited',
      'general_forum_topic_hidden',
      'general_forum_topic_unhidden',
      'video_chat_scheduled',
      'video_chat_started',
      'video_chat_ended',
      'video_chat_participants_invited',
    };
    for (final key in serviceKeys) {
      if (message.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  String? _extractMessageText(Map<String, dynamic> message) {
    final text = message['text']?.toString();
    if (text != null && text.trim().isNotEmpty) {
      return text;
    }
    final caption = message['caption']?.toString();
    if (caption != null && caption.trim().isNotEmpty) {
      return caption;
    }
    return null;
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
