import 'dart:io';

import 'package:args/args.dart';
import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';

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
    this.timezoneOffsetHours = 3,
    this.antiSpamEnabled = true,
    this.onboardingDripEnabled = true,
    this.trainingFeedbackEnabled = true,
    this.groupInviteNudgeEnabled = true,
    this.googleSheetsWriteEnabled = false,
    this.googleSheetsCredentialsPath,
    this.googleSheetsCredentialsJson,
    this.googleSheetsSpreadsheetId,
    this.googleSheetsWriteSheetTitle = 'FUNNEL',
    this.googleSheetsWriteIntervalSeconds = 300,
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
  final int timezoneOffsetHours;
  final bool antiSpamEnabled;
  final bool onboardingDripEnabled;
  final bool trainingFeedbackEnabled;
  final bool groupInviteNudgeEnabled;
  final bool googleSheetsWriteEnabled;
  final String? googleSheetsCredentialsPath;
  final String? googleSheetsCredentialsJson;
  final String? googleSheetsSpreadsheetId;
  final String googleSheetsWriteSheetTitle;
  final int googleSheetsWriteIntervalSeconds;

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
      ..addOption(
        'timezone-offset-hours',
        help: 'Business timezone offset in hours (default: 3)',
      )
      ..addOption(
        'anti-spam-enabled',
        help: 'Delete spam ads in group and ban senders (default: true)',
      )
      ..addOption(
        'onboarding-drip-enabled',
        help: 'Enable onboarding quiz/nudges for newcomers (default: true)',
      )
      ..addOption(
        'training-feedback-enabled',
        help: 'Ask anonymous feedback after trainings/hikes (default: true)',
      )
      ..addOption(
        'group-invite-nudge-enabled',
        help: 'Remind bot users who are not in the DVOR group (default: true)',
      )
      ..addOption(
        'google-sheets-write-enabled',
        help: 'Export bookings to Google Sheets (default: false)',
      )
      ..addOption(
        'google-sheets-credentials-path',
        help: 'Path to Google service-account JSON',
      )
      ..addOption(
        'google-sheets-credentials-json',
        help: 'Inline Google service-account JSON',
      )
      ..addOption(
        'google-sheets-spreadsheet-id',
        help: 'Google Spreadsheet id for write export',
      )
      ..addOption(
        'google-sheets-write-sheet-title',
        help: 'Sheet tab name overwritten by funnel dashboard (default: FUNNEL)',
      )
      ..addOption(
        'google-sheets-write-interval-seconds',
        help: 'Bookings export interval in seconds (default: 300)',
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

    final targetChatIdRaw = resolve('TARGET_CHAT_ID', 'target-chat-id', fallbackKey: 'CONFIG_CHATS')
        ?.split(',')
        .first
        .trim();
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
    final timezoneOffsetRaw = resolve('TIMEZONE_OFFSET_HOURS', 'timezone-offset-hours');
    final antiSpamEnabledRaw = resolve('ANTISPAM_ENABLED', 'anti-spam-enabled');
    final onboardingDripEnabledRaw = resolve('ONBOARDING_DRIP_ENABLED', 'onboarding-drip-enabled');
    final trainingFeedbackEnabledRaw =
        resolve('TRAINING_FEEDBACK_ENABLED', 'training-feedback-enabled');
    final groupInviteNudgeEnabledRaw =
        resolve('GROUP_INVITE_NUDGE_ENABLED', 'group-invite-nudge-enabled');
    final googleSheetsWriteEnabledRaw =
        resolve('GOOGLE_SHEETS_WRITE_ENABLED', 'google-sheets-write-enabled');
    final googleSheetsCredentialsPath =
        resolve('GOOGLE_SHEETS_CREDENTIALS_PATH', 'google-sheets-credentials-path');
    final googleSheetsCredentialsJson =
        resolve('GOOGLE_SHEETS_CREDENTIALS_JSON', 'google-sheets-credentials-json');
    final googleSheetsSpreadsheetIdRaw =
        resolve('GOOGLE_SHEETS_SPREADSHEET_ID', 'google-sheets-spreadsheet-id');
    final googleSheetsWriteSheetTitleRaw =
        resolve('GOOGLE_SHEETS_WRITE_SHEET_TITLE', 'google-sheets-write-sheet-title');
    final resolvedWriteSheetTitle = googleSheetsWriteSheetTitleRaw?.trim() ?? '';
    final googleSheetsWriteSheetTitle =
        resolvedWriteSheetTitle.isEmpty || resolvedWriteSheetTitle == 'bot_bookings'
            ? 'FUNNEL'
            : resolvedWriteSheetTitle;
    final googleSheetsWriteIntervalRaw = resolve(
      'GOOGLE_SHEETS_WRITE_INTERVAL_SECONDS',
      'google-sheets-write-interval-seconds',
    );

    final scheduleSource = _parseScheduleSource(scheduleSourceRaw);
    if (scheduleSource == ScheduleSource.googleSheets &&
        (googleSheetsCsvUrl == null || googleSheetsCsvUrl.isEmpty)) {
      stderr.writeln(
        'Missing Google Sheets URL. '
        'Use --google-sheets-csv-url or GOOGLE_SHEETS_CSV_URL.',
      );
      exit(2);
    }

    final googleSheetsWriteEnabled = _toBool(googleSheetsWriteEnabledRaw, defaultValue: false);
    final googleSheetsSpreadsheetId =
        (googleSheetsSpreadsheetIdRaw != null && googleSheetsSpreadsheetIdRaw.isNotEmpty)
            ? googleSheetsSpreadsheetIdRaw
            : spreadsheetIdFromSheetsUrl(googleSheetsCsvUrl);
    if (googleSheetsWriteEnabled) {
      final hasCredentials =
          (googleSheetsCredentialsPath != null && googleSheetsCredentialsPath.isNotEmpty) ||
              (googleSheetsCredentialsJson != null && googleSheetsCredentialsJson.isNotEmpty);
      if (!hasCredentials) {
        stderr.writeln(
          'GOOGLE_SHEETS_WRITE_ENABLED requires credentials. '
          'Use --google-sheets-credentials-path / GOOGLE_SHEETS_CREDENTIALS_PATH '
          'or GOOGLE_SHEETS_CREDENTIALS_JSON.',
        );
        exit(2);
      }
      if (googleSheetsSpreadsheetId == null || googleSheetsSpreadsheetId.isEmpty) {
        stderr.writeln(
          'GOOGLE_SHEETS_WRITE_ENABLED requires a spreadsheet id. '
          'Use --google-sheets-spreadsheet-id / GOOGLE_SHEETS_SPREADSHEET_ID '
          'or GOOGLE_SHEETS_CSV_URL.',
        );
        exit(2);
      }
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
      pendingPaymentTtlMinutes: int.tryParse(pendingPaymentTtlRaw ?? '')?.clamp(30, 1440) ?? 30,
      adminUserIds: _parseIntSet(adminUserIdsRaw),
      adminChatId: int.tryParse(adminChatIdRaw ?? ''),
      logLevel: logLevel,
      timezoneOffsetHours: int.tryParse(timezoneOffsetRaw ?? '')?.clamp(-12, 14) ?? 3,
      antiSpamEnabled: _toBool(antiSpamEnabledRaw, defaultValue: true),
      onboardingDripEnabled: _toBool(onboardingDripEnabledRaw, defaultValue: true),
      trainingFeedbackEnabled: _toBool(trainingFeedbackEnabledRaw, defaultValue: true),
      groupInviteNudgeEnabled: _toBool(groupInviteNudgeEnabledRaw, defaultValue: true),
      googleSheetsWriteEnabled: googleSheetsWriteEnabled,
      googleSheetsCredentialsPath: googleSheetsCredentialsPath,
      googleSheetsCredentialsJson: googleSheetsCredentialsJson,
      googleSheetsSpreadsheetId: googleSheetsSpreadsheetId,
      googleSheetsWriteSheetTitle: googleSheetsWriteSheetTitle,
      googleSheetsWriteIntervalSeconds:
          int.tryParse(googleSheetsWriteIntervalRaw ?? '')?.clamp(30, 86400) ?? 300,
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
    final value = _stripOptionalQuotes(trimmed.substring(idx + 1).trim());
    map[key] = value;
  }
  return map;
}

String _stripOptionalQuotes(String value) {
  if (value.length < 2) {
    return value;
  }
  final startsAndEndsWithSingle = value.startsWith("'") && value.endsWith("'");
  final startsAndEndsWithDouble = value.startsWith('"') && value.endsWith('"');
  if (startsAndEndsWithSingle || startsAndEndsWithDouble) {
    return value.substring(1, value.length - 1);
  }
  return value;
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
