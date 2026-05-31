import 'dart:io';

import 'package:args/args.dart';

final class AppConfig {
  const AppConfig({
    required this.botToken,
    required this.targetChatId,
    required this.sendGroupFallback,
    required this.pollTimeoutSeconds,
    required this.logLevel,
  });

  final String botToken;
  final int? targetChatId;
  final bool sendGroupFallback;
  final int pollTimeoutSeconds;
  final String logLevel;

  static AppConfig fromArgs(List<String> args) {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('token', abbr: 't', help: 'Telegram bot token')
      ..addOption('target-chat-id', help: 'Group chat id, e.g. -1001234567890')
      ..addOption('send-group-fallback', help: 'Send fallback in group if DM failed')
      ..addOption('poll-timeout-seconds', help: 'Long polling timeout in seconds')
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
    final logLevel = resolve('LOG_LEVEL', 'log-level', fallbackKey: 'CONFIG_VERBOSE') ?? 'info';

    return AppConfig(
      botToken: token,
      targetChatId: int.tryParse(targetChatIdRaw ?? ''),
      sendGroupFallback: _toBool(fallbackRaw, defaultValue: true),
      pollTimeoutSeconds: int.tryParse(pollTimeoutRaw ?? '')?.clamp(5, 60) ?? 25,
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
