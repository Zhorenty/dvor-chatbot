part of '../private_handlers.dart';

extension PrivateHandlersAdminSchedule on PrivateHandlers {
  static const List<String> _trainingCreateFields = <String>[
    'title',
    'date',
    'time',
    'location',
    'map',
    'coach',
    'price',
    'limit',
    'notes',
    'include_trainers',
    'promo_restricted',
  ];
  static const List<String> _outdoorCreateFields = <String>[
    'title',
    'date_from',
    'description',
    'date_to',
    'location',
    'price',
    'prepay',
    'limit',
    'equipment',
    'itinerary',
  ];

  Future<bool> _openAdminScheduleRoot({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
  }) async {
    if (!isAdmin) {
      await _sendAdminMessage(
        chatId,
        _templates.adminOnlyAction(),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }
    if (!_scheduleCatalogService.canEdit) {
      final text = _scheduleCatalogService.availability == ScheduleCatalogAvailability.staticSource
          ? _templates.adminScheduleUnavailableStatic()
          : _templates.adminScheduleWriteDisabled();
      await _sendAdminMessage(
        chatId,
        text,
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.selectingAdminScheduleRoot,
      availableTrainings: <TrainingInfo>[],
      adminSchedule: AdminScheduleFlow(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.adminScheduleRoot(),
      replyMarkup: _templates.adminScheduleRootInlineKeyboard(),
    );
    await _sender.sendMessage(
      chatId,
      'Назад — в админ-меню.',
      replyMarkup: _templates.adminScheduleNavKeyboard(),
    );
    return true;
  }

  Future<void> _openAdminScheduleList({
    required int chatId,
    required int userId,
    required ActivityCategory category,
    int page = 0,
  }) async {
    try {
      final items = await _scheduleCatalogService.listItems(category);
      final pageSize = PrivateHandlers._adminSchedulePageSize;
      final maxPage = items.isEmpty ? 0 : (items.length - 1) ~/ pageSize;
      final safePage = page.clamp(0, maxPage);
      _flowByUserId[userId] = (_flowByUserId[userId] ??
              const _PrivateFlowState(
                step: _PrivateFlowStep.selectingAdminScheduleList,
                availableTrainings: <TrainingInfo>[],
              ))
          .copyWith(
        step: _PrivateFlowStep.selectingAdminScheduleList,
        adminSchedule: AdminScheduleFlow(
          category: category,
          page: safePage,
          items: items,
        ),
      );
      final start = safePage * pageSize;
      final pageItems = items.skip(start).take(pageSize).toList(growable: false);
      final totalPages = items.isEmpty ? 1 : maxPage + 1;
      await _sendAdminMessage(
        chatId,
        _templates.adminScheduleList(
          category: category,
          shown: pageItems.length,
          total: items.length,
          page: safePage,
          totalPages: totalPages,
        ),
        replyMarkup: _templates.adminScheduleListInlineKeyboard(
          categoryCode: scheduleCategoryCode(category),
          itemLabels: [
            for (final item in pageItems) _adminScheduleItemLabel(item),
          ],
          page: safePage,
          pageSize: pageSize,
          totalCount: items.length,
        ),
      );
    } on ScheduleCatalogFailure catch (error) {
      await _sendAdminMessage(
        chatId,
        error.message ?? _templates.adminScheduleWriteDisabled(),
        replyMarkup: _templates.adminScheduleNavKeyboard(),
      );
    }
  }

  Future<void> _openAdminScheduleCard({
    required int chatId,
    required int userId,
    required int index,
    bool confirmingDelete = false,
  }) async {
    final flow = _flowByUserId[userId]?.adminSchedule;
    if (flow == null || index < 0 || index >= flow.items.length) {
      await _sendAdminMessage(chatId, _templates.adminScheduleNotFound());
      return;
    }
    final item = flow.items[index];
    final category = flow.category ?? item.category;
    _flowByUserId[userId] = _flowByUserId[userId]!.copyWith(
      step: confirmingDelete
          ? _PrivateFlowStep.confirmingAdminScheduleDelete
          : _PrivateFlowStep.viewingAdminScheduleEvent,
      adminSchedule: flow.copyWith(selectedIndex: index, field: null, wizard: null),
    );
    await _sendAdminMessage(
      chatId,
      confirmingDelete
          ? _templates.adminScheduleDeleteConfirm(item)
          : _templates.adminScheduleEventCard(item),
      replyMarkup: _templates.adminScheduleEventInlineKeyboard(
        categoryCode: scheduleCategoryCode(category),
        index: index,
        showTrainingToggles: item.isTraining && !confirmingDelete,
        includeTrainers: item.training?.includeTrainersInParticipants ?? false,
        promoRestricted: item.training?.promoRestricted ?? false,
        confirmingDelete: confirmingDelete,
      ),
    );
  }

  Future<void> _startAdminScheduleCreate({
    required int chatId,
    required int userId,
    required ActivityCategory category,
  }) async {
    final flow = _flowByUserId[userId]?.adminSchedule ?? const AdminScheduleFlow();
    _flowByUserId[userId] = (_flowByUserId[userId] ??
            const _PrivateFlowState(
              step: _PrivateFlowStep.enteringAdminScheduleField,
              availableTrainings: <TrainingInfo>[],
            ))
        .copyWith(
      step: _PrivateFlowStep.enteringAdminScheduleField,
      adminSchedule: flow.copyWith(
        category: category,
        draft: ScheduleEventDraft(category: category),
        field: _createFields(category).first,
        wizard: AdminScheduleWizardKind.create,
        awaitingCoachText: false,
        coachNames: _coachNames(),
      ),
    );
    await _promptAdminScheduleField(chatId: chatId, userId: userId);
  }

  Future<void> _promptAdminScheduleField({
    required int chatId,
    required int userId,
  }) async {
    final schedule = _flowByUserId[userId]?.adminSchedule;
    final field = schedule?.field;
    if (schedule == null || field == null) {
      return;
    }
    final optional = _isOptionalCreateField(field, schedule.category);
    Map<String, Object?> keyboard;
    if (field == 'include_trainers' || field == 'promo_restricted') {
      keyboard = _templates.adminScheduleBoolInlineKeyboard(optional: optional);
    } else if (field == 'coach' &&
        schedule.coachNames.isNotEmpty &&
        schedule.coachNames.length <= 8) {
      keyboard = _templates.adminScheduleCoachInlineKeyboard(
        schedule.coachNames,
        optional: optional,
      );
    } else {
      keyboard = _templates.adminScheduleSkipInlineKeyboard(showSkip: optional);
    }
    await _sendAdminMessage(
      chatId,
      _templates.adminScheduleFieldPrompt(field),
      replyMarkup: keyboard,
    );
  }

  Future<void> _advanceAdminScheduleCreate({
    required int chatId,
    required int userId,
  }) async {
    final state = _flowByUserId[userId];
    final schedule = state?.adminSchedule;
    final category = schedule?.category;
    final field = schedule?.field;
    if (state == null || schedule == null || category == null || field == null) {
      return;
    }
    final fields = _createFields(category);
    final index = fields.indexOf(field);
    if (index < 0 || index + 1 >= fields.length) {
      _flowByUserId[userId] = state.copyWith(
        step: _PrivateFlowStep.confirmingAdminScheduleCreate,
        adminSchedule: schedule.copyWith(field: null),
      );
      await _sendAdminMessage(
        chatId,
        _templates
            .adminScheduleCreatePreview(schedule.draft ?? ScheduleEventDraft(category: category)),
        replyMarkup: _templates.adminSchedulePreviewInlineKeyboard(),
      );
      return;
    }
    _flowByUserId[userId] = state.copyWith(
      adminSchedule: schedule.copyWith(field: fields[index + 1], awaitingCoachText: false),
    );
    await _promptAdminScheduleField(chatId: chatId, userId: userId);
  }

  Future<void> _applyAdminScheduleFieldValue({
    required int chatId,
    required int userId,
    required String raw,
  }) async {
    final state = _flowByUserId[userId];
    final schedule = state?.adminSchedule;
    final field = schedule?.field;
    final category = schedule?.category;
    if (state == null || schedule == null || field == null || category == null) {
      return;
    }
    if (field == 'include_trainers' || field == 'promo_restricted') {
      return;
    }
    final error = _scheduleCatalogService.validateField(
      category: category,
      field: field,
      raw: raw,
    );
    if (error != null) {
      await _sendAdminMessage(chatId, error);
      return;
    }
    if (schedule.wizard == AdminScheduleWizardKind.edit) {
      final selected = schedule.selected;
      if (selected == null) {
        await _sendAdminMessage(chatId, _templates.adminScheduleNotFound());
        return;
      }
      final patch = _scheduleCatalogService.applyField(
        draft: ScheduleEventDraft(category: category),
        field: field,
        raw: raw,
      );
      final result = await _scheduleCatalogService.update(identity: selected, patch: patch);
      await _handleAdminScheduleWrite(
        chatId: chatId,
        userId: userId,
        result: result,
        reopenCard: true,
      );
      return;
    }
    final draft = _scheduleCatalogService.applyField(
      draft: schedule.draft ?? ScheduleEventDraft(category: category),
      field: field,
      raw: raw,
    );
    _flowByUserId[userId] = state.copyWith(adminSchedule: schedule.copyWith(draft: draft));
    await _advanceAdminScheduleCreate(chatId: chatId, userId: userId);
  }

  Future<void> _handleAdminScheduleWrite({
    required int chatId,
    required int userId,
    required ScheduleCatalogWriteResult result,
    required bool reopenCard,
  }) async {
    if (!result.isOk) {
      await _sendAdminMessage(
        chatId,
        result.message ?? _templates.adminScheduleNotFound(),
      );
      return;
    }
    await _sendAdminMessage(
      chatId,
      _templates.adminScheduleSaved(refreshOk: result.refreshOk),
    );
    final category = _flowByUserId[userId]?.adminSchedule.category;
    if (category == null) {
      return;
    }
    if (reopenCard && result.item != null) {
      await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
      final items = _flowByUserId[userId]?.adminSchedule.items ?? const <ScheduleCatalogItem>[];
      final index = items.indexWhere((item) => item.matchesIdentity(result.item!));
      if (index >= 0) {
        await _openAdminScheduleCard(chatId: chatId, userId: userId, index: index);
      }
      return;
    }
    await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
  }

  List<String> _createFields(ActivityCategory category) {
    return category == ActivityCategory.trainings ? _trainingCreateFields : _outdoorCreateFields;
  }

  bool _isOptionalCreateField(String field, ActivityCategory? category) {
    if (field == 'title' ||
        field == 'date' ||
        field == 'time' ||
        field == 'date_from' ||
        field == 'description') {
      return false;
    }
    if (field == 'location' && category == ActivityCategory.trainings) {
      return false;
    }
    return true;
  }

  List<(String, String)> _editFields(ActivityCategory category) {
    if (category == ActivityCategory.trainings) {
      return const <(String, String)>[
        ('title', 'название'),
        ('date', 'дата'),
        ('time', 'время'),
        ('location', 'место'),
        ('map', 'карта'),
        ('coach', 'тренер'),
        ('price', 'цена'),
        ('limit', 'лимит'),
        ('notes', 'заметки'),
      ];
    }
    return const <(String, String)>[
      ('title', 'название'),
      ('date_from', 'дата_с'),
      ('date_to', 'дата_по'),
      ('description', 'описание'),
      ('location', 'место'),
      ('price', 'цена'),
      ('prepay', 'предоплата'),
      ('limit', 'лимит'),
      ('equipment', 'экипировка'),
      ('itinerary', 'план'),
    ];
  }

  List<String> _coachNames() {
    return _trainerDirectoryRepository
        .list(limit: 8)
        .map((trainer) => trainer.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  String _adminScheduleItemLabel(ScheduleCatalogItem item) {
    final date = DateFormat('dd.MM').format(item.sortAt);
    final raw = '$date ${item.title}';
    if (raw.length <= 40) {
      return raw;
    }
    return '${raw.substring(0, 37)}…';
  }

  (ActivityCategory, int)? _parseAdminSchedRef(String rest) {
    final parts = rest.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final category = scheduleCategoryFromCode(parts[0]);
    final index = int.tryParse(parts[1]);
    if (category == null || index == null) {
      return null;
    }
    return (category, index);
  }
}
