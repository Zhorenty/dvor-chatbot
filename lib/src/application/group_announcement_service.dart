import 'dart:async';

import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

/// Types of automatic group announcements, ordered by business priority.
///
/// Higher [priority] wins the single announcement slot in the target group.
enum GroupAnnouncementType {
  /// Lowest priority.
  referralBroadcast(1),
  lowSpots(2),
  scheduleBroadcast(3),
  noSpots(4),

  /// Highest priority.
  trainingDayPromo(5);

  const GroupAnnouncementType(this.priority);

  final int priority;
}

final class _ActiveAnnouncement {
  const _ActiveAnnouncement({
    required this.messageId,
    required this.type,
    required this.sentAt,
  });

  final int messageId;
  final GroupAnnouncementType type;
  final DateTime sentAt;
}

/// Coordinates automatic posts in the target group so only one announcement
/// is active at a time, with priority-based replacement.
final class GroupAnnouncementService {
  GroupAnnouncementService({
    required MessageSender sender,
    Duration slotTtl = const Duration(hours: 3),
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _slotTtl = slotTtl,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final Duration _slotTtl;
  final DateTime Function() _nowProvider;

  _ActiveAnnouncement? _active;
  Future<void> _chain = Future<void>.value();

  /// Publishes [text] if it may take the announcement slot.
  ///
  /// Returns `true` when a message was sent. Returns `false` when skipped
  /// because a higher-priority announcement still occupies the slot.
  /// Concurrent callers are serialized so slot checks cannot interleave.
  Future<bool> publish({
    required int chatId,
    required GroupAnnouncementType type,
    required String text,
    String? parseMode,
    bool disableWebPagePreview = true,
    Map<String, Object?>? replyMarkup,
  }) {
    final completer = Completer<bool>();
    _chain = _chain.then((_) async {
      try {
        final sent = await _publishLocked(
          chatId: chatId,
          type: type,
          text: text,
          parseMode: parseMode,
          disableWebPagePreview: disableWebPagePreview,
          replyMarkup: replyMarkup,
        );
        completer.complete(sent);
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<bool> _publishLocked({
    required int chatId,
    required GroupAnnouncementType type,
    required String text,
    required String? parseMode,
    required bool disableWebPagePreview,
    Map<String, Object?>? replyMarkup,
  }) async {
    final now = _nowProvider();
    final active = _active;
    final slotExpired = active == null || now.difference(active.sentAt) >= _slotTtl;
    if (!slotExpired && type.priority < active.type.priority) {
      l.i(
        'Skipping group announcement ${type.name}: '
        'active ${active.type.name} has higher priority',
      );
      return false;
    }

    final previousMessageId = active?.messageId;
    if (previousMessageId != null) {
      try {
        await _sender.deleteMessage(chatId, messageId: previousMessageId);
      } on Object catch (error, stackTrace) {
        l.w(
          'Failed to delete previous group announcement $previousMessageId: $error',
          stackTrace,
        );
      }
    }

    final messageId = await _sender.sendMessage(
      chatId,
      text,
      parseMode: parseMode,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup,
    );
    _active = _ActiveAnnouncement(
      messageId: messageId,
      type: type,
      sentAt: now,
    );
    return true;
  }
}
