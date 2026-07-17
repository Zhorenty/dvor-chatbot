import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:test/test.dart';

void main() {
  group('AppConfig.fromArgs', () {
    test('parses explicit CLI options', () {
      final config = AppConfig.fromArgs(<String>[
        '--token',
        'cli-token',
        '--target-chat-id',
        '-100123456',
        '--send-group-fallback',
        'false',
        '--poll-timeout-seconds',
        '45',
        '--schedule-source',
        'google_sheets',
        '--google-sheets-csv-url',
        'https://example.com/sheet.csv',
        '--schedule-sync-interval-seconds',
        '900',
        '--admin-user-ids',
        '1001, 1002, bad,1001',
        '--admin-chat-id',
        '-100777',
        '--bookings-db-path',
        'tmp/bookings.sqlite',
        '--pending-payment-ttl-minutes',
        '180',
        '--log-level',
        'debug',
      ]);

      expect(config.botToken, 'cli-token');
      expect(config.targetChatId, -100123456);
      expect(config.sendGroupFallback, isFalse);
      expect(config.pollTimeoutSeconds, 45);
      expect(config.scheduleSource, ScheduleSource.googleSheets);
      expect(config.googleSheetsCsvUrl, 'https://example.com/sheet.csv');
      expect(config.scheduleSyncIntervalSeconds, 900);
      expect(config.adminUserIds, <int>{1001, 1002});
      expect(config.adminChatId, -100777);
      expect(config.bookingsDbPath, 'tmp/bookings.sqlite');
      expect(config.pendingPaymentTtlMinutes, 180);
      expect(config.logLevel, 'debug');
    });

    test('uses defaults and clamps invalid values', () {
      final config = AppConfig.fromArgs(<String>[
        '--token',
        'cli-token',
        '--target-chat-id',
        '',
        '--google-sheets-csv-url',
        '',
        '--admin-user-ids',
        '',
        '--admin-chat-id',
        '',
        '--poll-timeout-seconds',
        '999',
        '--schedule-sync-interval-seconds',
        '10',
        '--pending-payment-ttl-minutes',
        '1',
        '--schedule-source',
        'unknown',
      ]);

      expect(config.botToken, 'cli-token');
      expect(config.targetChatId, isNull);
      expect(config.sendGroupFallback, isTrue);
      expect(config.pollTimeoutSeconds, 60);
      expect(config.scheduleSource, ScheduleSource.staticData);
      expect(config.googleSheetsCsvUrl, anyOf(isNull, ''));
      expect(config.scheduleSyncIntervalSeconds, 30);
      expect(config.bookingsDbPath, 'data/bookings.sqlite');
      expect(config.pendingPaymentTtlMinutes, 30);
      expect(config.adminUserIds, isEmpty);
      expect(config.adminChatId, isNull);
      expect(config.logLevel, 'info');
    });

    test('trims first target chat id when csv-like value is passed', () {
      final config = AppConfig.fromArgs(<String>[
        '--token',
        'cli-token',
        '--target-chat-id',
        ' -100123456, -100999999',
      ]);

      expect(config.targetChatId, -100123456);
    });
  });
}
