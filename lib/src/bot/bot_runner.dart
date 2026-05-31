import 'dart:async';

import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:l/l.dart';

final class BotRunner {
  BotRunner({
    required AppConfig config,
    required TelegramClient client,
    required TrainingScheduleRepository scheduleRepository,
    required PrivateHandlers privateHandlers,
    required GroupHandlers groupHandlers,
  })  : _config = config,
        _client = client,
        _scheduleRepository = scheduleRepository,
        _privateHandlers = privateHandlers,
        _groupHandlers = groupHandlers;

  final AppConfig _config;
  final TelegramClient _client;
  final TrainingScheduleRepository _scheduleRepository;
  final PrivateHandlers _privateHandlers;
  final GroupHandlers _groupHandlers;

  bool _stopping = false;
  int _offset = 0;
  String? _botUsername;
  Timer? _scheduleSyncTimer;

  Future<void> start() async {
    final initialRefreshOk = await _scheduleRepository.refresh(force: true);
    if (!initialRefreshOk) {
      l.w('Initial schedule refresh failed. Continuing with available cache.');
    }
    _scheduleSyncTimer = Timer.periodic(
      Duration(seconds: _config.scheduleSyncIntervalSeconds),
      (_) {
        if (_stopping) {
          return;
        }
        unawaited(_refreshScheduleInBackground());
      },
    );

    try {
      _botUsername = await _client.getBotUsername();
      l.i('Bot username: ${_botUsername ?? 'unknown'}');
    } on TelegramApiException catch (error, stackTrace) {
      l.w('Failed to resolve bot username: $error', stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      l.w('Timed out resolving bot username: $error', stackTrace);
    } on Object catch (error, stackTrace) {
      l.w('Unexpected error resolving bot username: $error', stackTrace);
    }

    while (!_stopping) {
      try {
        final updates = await _client.getUpdates(
          offset: _offset,
          timeoutSeconds: _config.pollTimeoutSeconds,
          allowedUpdates: const {'message'},
        );
        for (final update in updates) {
          if (_stopping) {
            break;
          }
          final updateId = update['update_id'];
          if (updateId is int) {
            _offset = updateId + 1;
          }
          await _handleUpdate(update);
        }
      } on TelegramApiException catch (error, stackTrace) {
        l.w('Telegram API error in polling loop: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      } on TimeoutException catch (error, stackTrace) {
        l.w('Polling timeout: $error', stackTrace);
      } on Object catch (error, stackTrace) {
        l.e('Unexpected polling error: $error', stackTrace);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _handleUpdate(Map<String, dynamic> update) async {
    final message = update['message'];
    if (message is! Map) {
      return;
    }
    final normalized = Map<String, dynamic>.from(message);
    final privateHandled = await _privateHandlers.handle(normalized);
    if (privateHandled) {
      return;
    }
    await _groupHandlers.handle(normalized, botUsername: _botUsername);
  }

  Future<void> _refreshScheduleInBackground() async {
    final refreshOk = await _scheduleRepository.refresh();
    if (!refreshOk) {
      l.w('Background schedule refresh failed.');
    }
  }

  void stop() {
    _stopping = true;
    _scheduleSyncTimer?.cancel();
    _client.close();
  }
}
