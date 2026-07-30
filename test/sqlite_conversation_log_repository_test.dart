import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_conversation_log_repository.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteConversationLogRepository', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-conversation-log-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('stores inbound/outbound and resolves username', () async {
      final repository = SqliteConversationLogRepository(
        dbPath: '${tmpDir.path}/log.sqlite',
        nowProvider: () => DateTime.utc(2030, 7, 1, 12),
      );
      await repository.init();

      await repository.append(
        direction: ConversationDirection.inbound,
        peerUserId: 42,
        peerUsername: '@Runner',
        chatId: 42,
        telegramMessageId: 11,
        contentType: ConversationContentType.text,
        textPreview: 'привет',
      );
      await repository.append(
        direction: ConversationDirection.outbound,
        peerUserId: 42,
        peerUsername: 'runner',
        chatId: 42,
        telegramMessageId: 12,
        contentType: ConversationContentType.text,
        textPreview: '<b>ответ</b>',
      );

      expect(await repository.resolveUserIdByUsername('@runner'), 42);

      final dialog = await repository.dialogForUserId(42);
      expect(dialog, hasLength(2));
      expect(dialog.first.direction, ConversationDirection.inbound);
      expect(dialog.last.textPreview, 'ответ');

      final recent = await repository.recentActions(limit: 10);
      expect(recent.first.direction, ConversationDirection.outbound);

      await repository.close();
    });

    test('excludes peer ids from recent actions', () async {
      final repository = SqliteConversationLogRepository(
        dbPath: '${tmpDir.path}/log.sqlite',
      );
      await repository.init();

      await repository.append(
        direction: ConversationDirection.outbound,
        peerUserId: 1,
        chatId: 1,
        telegramMessageId: 1,
        contentType: ConversationContentType.text,
        textPreview: 'admin',
      );
      await repository.append(
        direction: ConversationDirection.inbound,
        peerUserId: 2,
        peerUsername: 'client',
        chatId: 2,
        telegramMessageId: 2,
        contentType: ConversationContentType.text,
        textPreview: 'hi',
      );

      final recent = await repository.recentActions(excludePeerIds: const <int>{1});
      expect(recent, hasLength(1));
      expect(recent.single.peerUserId, 2);

      await repository.close();
    });
  });
}
