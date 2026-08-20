import 'package:dvor_chatbot/src/application/schedule_catalog_service.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/schedule_retention_job.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/keyboards/telegram_keyboards.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';

void main() {
  group('admin schedule CRUD', () {
    test('admin sees schedule button and opens CRUD root', () async {
      final catalog = FakeScheduleCatalogRepository();
      final harness = _harness(catalog);

      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: '/start',
      );
      expect(
        _keyboardTexts(harness.sender.messages.single.replyMarkup),
        contains(MessageTemplates.buttonAdminSchedule),
      );

      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: MessageTemplates.buttonAdminSchedule,
      );
      expect(
        harness.sender.messages.any((item) => item.text.contains('Выбери вкладку')),
        isTrue,
      );
      expect(
        _inlineCallbacks(harness.sender.messages[harness.sender.messages.length - 2].replyMarkup),
        contains('${MessageCopy.callbackAdminSchedCatPrefix}t'),
      );
    });

    test('non-admin does not get schedule CRUD', () async {
      final harness = PrivateHandlersHarness(
        adminUserIds: const <int>{9100},
        scheduleCatalogService: ScheduleCatalogService(
          catalogRepository: FakeScheduleCatalogRepository(),
          scheduleRepository: FakeScheduleRepository(const <TrainingInfo>[]),
        ),
      );

      await harness.handleText(chatId: 42, userId: 42, text: '/start');
      expect(
        _keyboardTexts(harness.sender.messages.single.replyMarkup),
        isNot(contains(MessageTemplates.buttonManageBookings)),
      );

      await harness.handleCallback(
        callbackId: 'cb1',
        chatId: 42,
        userId: 42,
        data: '${MessageCopy.callbackAdminSchedCatPrefix}t',
      );
      expect(harness.sender.messages.last.text, contains('только администраторам'));
    });

    test('callback opens event card', () async {
      final catalog = FakeScheduleCatalogRepository(
        items: <ScheduleCatalogItem>[
          ScheduleCatalogItem(
            sheetRow: 2,
            category: ActivityCategory.trainings,
            training: TrainingInfo(
              title: 'BOXING DVOR',
              startsAt: DateTime(2026, 8, 20, 19, 30),
              location: 'Стадион',
            ),
          ),
        ],
      );
      final harness = _harness(catalog);

      await harness.handleCallback(
        callbackId: 'cb1',
        chatId: 9100,
        userId: 9100,
        data: '${MessageCopy.callbackAdminSchedCatPrefix}t',
      );
      await harness.handleCallback(
        callbackId: 'cb2',
        chatId: 9100,
        userId: 9100,
        data: '${MessageCopy.callbackAdminSchedOpenPrefix}t:0',
      );

      expect(harness.sender.messages.last.text, contains('BOXING DVOR'));
      expect(
        _inlineCallbacks(harness.sender.messages.last.replyMarkup),
        contains('${MessageCopy.callbackAdminSchedEditPrefix}t:0'),
      );
    });

    test('create saves and refreshes schedule cache', () async {
      final catalog = FakeScheduleCatalogRepository();
      final harness = _harness(catalog);

      await harness.handleCallback(
        callbackId: 'add',
        chatId: 9100,
        userId: 9100,
        data: '${MessageCopy.callbackAdminSchedAddPrefix}t',
      );
      await harness.handleText(chatId: 9100, userId: 9100, text: 'BOXING DVOR');
      await harness.handleText(chatId: 9100, userId: 9100, text: '19.08.2026');
      await harness.handleText(chatId: 9100, userId: 9100, text: '19:30');
      await harness.handleText(chatId: 9100, userId: 9100, text: 'Стадион Кубань');
      for (var i = 0; i < 7; i++) {
        await harness.handleCallback(
          callbackId: 'skip$i',
          chatId: 9100,
          userId: 9100,
          data: MessageCopy.callbackAdminSchedSkip,
        );
      }
      await harness.handleCallback(
        callbackId: 'save',
        chatId: 9100,
        userId: 9100,
        data: MessageCopy.callbackAdminSchedSave,
      );

      expect(catalog.createdDrafts, hasLength(1));
      expect(catalog.createdDrafts.single.title, 'BOXING DVOR');
      expect(
        harness.sender.messages.any((item) => item.text.contains('Записал в таблицу')),
        isTrue,
      );
    });

    test('write disabled shows a clear error', () async {
      final harness = _harness(
        FakeScheduleCatalogRepository(availability: ScheduleCatalogAvailability.writeDisabled),
      );

      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: MessageTemplates.buttonAdminSchedule,
      );

      expect(harness.sender.messages.last.text, contains('Запись в таблицу выключена'));
    });

    test('static source refuses CRUD', () async {
      final harness = _harness(
        FakeScheduleCatalogRepository(availability: ScheduleCatalogAvailability.staticSource),
      );

      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: MessageTemplates.buttonAdminSchedule,
      );

      expect(harness.sender.messages.last.text, contains('не Google Sheets'));
    });

    test('admin in client mode does not open schedule CRUD', () async {
      final catalog = FakeScheduleCatalogRepository();
      final harness = _harness(catalog);

      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: MessageTemplates.buttonClientMenu,
      );
      await harness.handleText(
        chatId: 9100,
        userId: 9100,
        text: MessageTemplates.buttonTrainings,
      );

      expect(harness.sender.messages.last.text, isNot(contains('Выбери вкладку')));
      expect(catalog.createdDrafts, isEmpty);
    });
  });

  group('admin schedule keyboards', () {
    test('callback_data stays within 64 bytes', () {
      final callbacks = <String>{
        ..._inlineCallbacks(TelegramKeyboards.adminScheduleRootInlineKeyboard()),
        ..._inlineCallbacks(
          TelegramKeyboards.adminScheduleListInlineKeyboard(
            categoryCode: 't',
            itemLabels: const <String>['20.08 BOXING'],
            page: 12,
            pageSize: 8,
            totalCount: 120,
          ),
        ),
        ..._inlineCallbacks(
          TelegramKeyboards.adminScheduleEventInlineKeyboard(
            categoryCode: 't',
            index: 179,
            showTrainingToggles: true,
          ),
        ),
        ..._inlineCallbacks(
          TelegramKeyboards.adminScheduleEventInlineKeyboard(
            categoryCode: 'h',
            index: 179,
            confirmingDelete: true,
          ),
        ),
        ..._inlineCallbacks(
          TelegramKeyboards.adminScheduleFieldsInlineKeyboard(const <(String, String)>[
            ('date_from', 'дата_с'),
            ('include_trainers', 'тренеры в лимите'),
          ]),
        ),
        ..._inlineCallbacks(TelegramKeyboards.adminScheduleBoolInlineKeyboard(optional: true)),
        ..._inlineCallbacks(
          TelegramKeyboards.adminScheduleCoachInlineKeyboard(
            const <String>['Алексей'],
            optional: true,
          ),
        ),
        ..._inlineCallbacks(TelegramKeyboards.adminSchedulePreviewInlineKeyboard()),
      };

      for (final callback in callbacks) {
        expect(callback.length, lessThanOrEqualTo(64), reason: callback);
      }
    });
  });

  group('ScheduleRetentionJob', () {
    test('no-ops when write is disabled', () async {
      final catalog = FakeScheduleCatalogRepository(
        availability: ScheduleCatalogAvailability.writeDisabled,
      );
      final schedule = FakeScheduleRepository(const <TrainingInfo>[]);
      final job = ScheduleRetentionJob(
        catalogService: ScheduleCatalogService(
          catalogRepository: catalog,
          scheduleRepository: schedule,
        ),
        scheduleRepository: schedule,
      );

      await job.run();

      expect(catalog.lastRetentionNow, isNull);
      expect(schedule.refreshCalls, 0);
    });

    test('refreshes cache after deleting rows', () async {
      final catalog = FakeScheduleCatalogRepository()
        ..retentionResult = const ScheduleRetentionResult(trainingsDeleted: 2);
      final schedule = FakeScheduleRepository(const <TrainingInfo>[]);
      final job = ScheduleRetentionJob(
        catalogService: ScheduleCatalogService(
          catalogRepository: catalog,
          scheduleRepository: schedule,
        ),
        scheduleRepository: schedule,
      );

      await job.run();

      expect(catalog.lastRetentionNow, isNotNull);
      expect(schedule.refreshCalls, 1);
    });
  });
}

PrivateHandlersHarness _harness(FakeScheduleCatalogRepository catalog) {
  final schedule = FakeScheduleRepository(const <TrainingInfo>[]);
  return PrivateHandlersHarness(
    adminUserIds: const <int>{9100},
    scheduleCatalogService: ScheduleCatalogService(
      catalogRepository: catalog,
      scheduleRepository: schedule,
    ),
  );
}

Set<String> _keyboardTexts(Map<String, Object?>? keyboard) {
  final rowsRaw = keyboard?['keyboard'];
  if (rowsRaw is! List) {
    return const <String>{};
  }
  final result = <String>{};
  for (final row in rowsRaw) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['text'] is String) {
        result.add(button['text']! as String);
      }
    }
  }
  return result;
}

Set<String> _inlineCallbacks(Map<String, Object?>? keyboard) {
  final rowsRaw = keyboard?['inline_keyboard'];
  if (rowsRaw is! List) {
    return const <String>{};
  }
  final result = <String>{};
  for (final row in rowsRaw) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['callback_data'] is String) {
        result.add(button['callback_data']! as String);
      }
    }
  }
  return result;
}
