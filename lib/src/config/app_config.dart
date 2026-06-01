import 'dart:io';

import 'package:args/args.dart';

enum ScheduleSource { staticData, googleSheets }

final class AppConfig {
  const AppConfig({
    required this.botToken,
    required this.targetChatId,
    required this.sendGroupFallback,
    required this.pollTimeoutSeconds,
    required this.scheduleSource,
    required this.googleSheetsCsvUrl,
    required this.scheduleSyncIntervalSeconds,
    required this.bookingsDbPath,
    required this.pendingPaymentTtlMinutes,
    required this.adminUserIds,
    required this.adminChatId,
    required this.logLevel,
  });

  final String botToken;
  final int? targetChatId;
  final bool sendGroupFallback;
  final int pollTimeoutSeconds;
  final ScheduleSource scheduleSource;
  final String? googleSheetsCsvUrl;
  final int scheduleSyncIntervalSeconds;
  final String bookingsDbPath;
  final int pendingPaymentTtlMinutes;
  final Set<int> adminUserIds;
  final int? adminChatId;
  final String logLevel;

  static AppConfig fromArgs(List<String> args) {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('token', abbr: 't', help: 'Telegram bot token')
      ..addOption('target-chat-id', help: 'Group chat id, e.g. -1001234567890')
      ..addOption('send-group-fallback', help: 'Send fallback in group if DM failed')
      ..addOption('poll-timeout-seconds', help: 'Long polling timeout in seconds')
      ..addOption(
        'schedule-source',
        help: 'Schedule source: static or google_sheets',
      )
      ..addOption(
        'google-sheets-csv-url',
        help: 'Google Sheets CSV export URL',
      )
      ..addOption(
        'schedule-sync-interval-seconds',
        help: 'Schedule sync interval for background refresh',
      )
      ..addOption(
        'admin-user-ids',
        help: 'Comma-separated Telegram user ids with admin actions',
      )
      ..addOption(
        'admin-chat-id',
        help: 'Telegram chat id for admin notifications',
      )
      ..addOption(
        'bookings-db-path',
        help: 'SQLite path for bookings storage',
      )
      ..addOption(
        'pending-payment-ttl-minutes',
        help: 'TTL (minutes) before unpaid booking auto-cancel',
      )
      ..addOption('log-level', help: 'Log level: debug/info/warn/error');

    final result = parser.parse(args);
    if (result['help'] == true) {
      stdout
        ..writeln('DVOR Telegram bot')
        ..writeln()
        ..writeln(parser.usage);
      exit(0);
    }

    final dotenv = _readDotEnv();
    final env = Platform.environment;

    String? resolve(String key, String cliName, {String? fallbackKey}) {
      if (result.wasParsed(cliName)) {
        return result[cliName]?.toString();
      }
      if (env[key] case final String value when value.isNotEmpty) {
        return value;
      }
      if (fallbackKey != null) {
        final fallbackValue = env[fallbackKey];
        if (fallbackValue != null && fallbackValue.isNotEmpty) {
          return fallbackValue;
        }
      }
      if (dotenv[key] case final String value when value.isNotEmpty) {
        return value;
      }
      if (fallbackKey != null) {
        final fallbackValue = dotenv[fallbackKey];
        if (fallbackValue != null && fallbackValue.isNotEmpty) {
          return fallbackValue;
        }
      }
      return null;
    }

    final token = resolve('BOT_TOKEN', 'token', fallbackKey: 'CONFIG_TOKEN');
    if (token == null || token.isEmpty) {
      stderr.writeln('Missing bot token. Use --token or BOT_TOKEN/CONFIG_TOKEN.');
      exit(2);
    }

    final targetChatIdRaw =
        resolve('TARGET_CHAT_ID', 'target-chat-id', fallbackKey: 'CONFIG_CHATS')?.split(',').first;
    final pollTimeoutRaw = resolve('POLL_TIMEOUT_SECONDS', 'poll-timeout-seconds');
    final fallbackRaw = resolve('SEND_GROUP_FALLBACK', 'send-group-fallback');
    final scheduleSourceRaw = resolve('SCHEDULE_SOURCE', 'schedule-source');
    final googleSheetsCsvUrl = resolve('GOOGLE_SHEETS_CSV_URL', 'google-sheets-csv-url');
    final scheduleSyncIntervalRaw =
        resolve('SCHEDULE_SYNC_INTERVAL_SECONDS', 'schedule-sync-interval-seconds');
    final adminUserIdsRaw = resolve('ADMIN_USER_IDS', 'admin-user-ids');
    final adminChatIdRaw = resolve('ADMIN_CHAT_ID', 'admin-chat-id');
    final bookingsDbPath =
        resolve('BOOKINGS_DB_PATH', 'bookings-db-path') ?? 'data/bookings.sqlite';
    final pendingPaymentTtlRaw =
        resolve('PENDING_PAYMENT_TTL_MINUTES', 'pending-payment-ttl-minutes');
    final logLevel = resolve('LOG_LEVEL', 'log-level', fallbackKey: 'CONFIG_VERBOSE') ?? 'info';

    final scheduleSource = _parseScheduleSource(scheduleSourceRaw);
    if (scheduleSource == ScheduleSource.googleSheets &&
        (googleSheetsCsvUrl == null || googleSheetsCsvUrl.isEmpty)) {
      stderr.writeln(
        'Missing Google Sheets URL. '
        'Use --google-sheets-csv-url or GOOGLE_SHEETS_CSV_URL.',
      );
      exit(2);
    }

    return AppConfig(
      botToken: token,
      targetChatId: int.tryParse(targetChatIdRaw ?? ''),
      sendGroupFallback: _toBool(fallbackRaw, defaultValue: true),
      pollTimeoutSeconds: int.tryParse(pollTimeoutRaw ?? '')?.clamp(5, 60) ?? 25,
      scheduleSource: scheduleSource,
      googleSheetsCsvUrl: googleSheetsCsvUrl,
      scheduleSyncIntervalSeconds:
          int.tryParse(scheduleSyncIntervalRaw ?? '')?.clamp(30, 86400) ?? 300,
      bookingsDbPath: bookingsDbPath,
      pendingPaymentTtlMinutes: int.tryParse(pendingPaymentTtlRaw ?? '')?.clamp(5, 1440) ?? 120,
      adminUserIds: _parseIntSet(adminUserIdsRaw),
      adminChatId: int.tryParse(adminChatIdRaw ?? ''),
      logLevel: logLevel,
    );
  }
}

Map<String, String> _readDotEnv() {
  final file = File('.env');
  if (!file.existsSync()) {
    return const <String, String>{};
  }

  final map = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final idx = trimmed.indexOf('=');
    if (idx <= 0) {
      continue;
    }
    final key = trimmed.substring(0, idx).trim();
    final value = trimmed.substring(idx + 1).trim();
    map[key] = value;
  }
  return map;
}

bool _toBool(String? value, {required bool defaultValue}) {
  if (value == null) {
    return defaultValue;
  }
  switch (value.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return defaultValue;
  }
}

ScheduleSource _parseScheduleSource(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'google_sheets':
    case 'google-sheets':
      return ScheduleSource.googleSheets;
    case null:
    case '':
    case 'static':
    case 'static_data':
    case 'static-data':
      return ScheduleSource.staticData;
    default:
      return ScheduleSource.staticData;
  }
}

Set<int> _parseIntSet(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <int>{};
  }
  return raw.split(',').map((item) => int.tryParse(item.trim())).whereType<int>().toSet();
}
