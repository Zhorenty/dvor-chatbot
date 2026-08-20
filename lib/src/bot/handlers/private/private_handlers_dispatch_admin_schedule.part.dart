part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminSchedule on PrivateHandlers {
  Future<bool> _dispatchAdminScheduleCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    if (userId == null || text == null) {
      return false;
    }

    if (isAdmin &&
        (text == MessageTemplates.buttonAdminSchedule ||
            text == MessageTemplates.buttonTrainings)) {
      return _openAdminScheduleRoot(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
    }

    if (!text.startsWith('/admin_sched_') &&
        ctx.flowState?.step != _PrivateFlowStep.enteringAdminScheduleField &&
        ctx.flowState?.step != _PrivateFlowStep.confirmingAdminScheduleCreate &&
        ctx.flowState?.step != _PrivateFlowStep.confirmingAdminScheduleDelete &&
        ctx.flowState?.step != _PrivateFlowStep.viewingAdminScheduleEvent &&
        ctx.flowState?.step != _PrivateFlowStep.selectingAdminScheduleList &&
        ctx.flowState?.step != _PrivateFlowStep.selectingAdminScheduleRoot) {
      return false;
    }

    if (!isAdmin) {
      if (text.startsWith('/admin_sched_')) {
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
      return false;
    }

    if (text == '/admin_sched_root') {
      return _openAdminScheduleRoot(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
    }

    if (text.startsWith('/admin_sched_cat ')) {
      final category = scheduleCategoryFromCode(text.substring('/admin_sched_cat '.length).trim());
      if (category == null) {
        return true;
      }
      await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
      return true;
    }

    if (text.startsWith('/admin_sched_page ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_page '.length));
      if (parsed == null) {
        return true;
      }
      await _openAdminScheduleList(
        chatId: chatId,
        userId: userId,
        category: parsed.$1,
        page: parsed.$2,
      );
      return true;
    }

    if (text.startsWith('/admin_sched_open ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_open '.length));
      if (parsed == null) {
        return true;
      }
      if (ctx.flowState?.adminSchedule.category != parsed.$1) {
        await _openAdminScheduleList(chatId: chatId, userId: userId, category: parsed.$1);
      }
      await _openAdminScheduleCard(chatId: chatId, userId: userId, index: parsed.$2);
      return true;
    }

    if (text.startsWith('/admin_sched_add ')) {
      final category = scheduleCategoryFromCode(text.substring('/admin_sched_add '.length).trim());
      if (category == null) {
        return true;
      }
      await _startAdminScheduleCreate(chatId: chatId, userId: userId, category: category);
      return true;
    }

    if (text.startsWith('/admin_sched_ref ')) {
      final category = scheduleCategoryFromCode(text.substring('/admin_sched_ref '.length).trim());
      if (category == null) {
        return true;
      }
      await _scheduleCatalogService.refreshSchedule();
      await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
      return true;
    }

    if (text.startsWith('/admin_sched_edit ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_edit '.length));
      if (parsed == null) {
        return true;
      }
      if (ctx.flowState?.adminSchedule.selectedIndex != parsed.$2) {
        await _openAdminScheduleCard(chatId: chatId, userId: userId, index: parsed.$2);
      }
      final state = _flowByUserId[userId];
      final schedule = state?.adminSchedule;
      if (state == null || schedule == null) {
        return true;
      }
      _flowByUserId[userId] = state.copyWith(
        step: _PrivateFlowStep.enteringAdminScheduleField,
        adminSchedule: schedule.copyWith(
          field: null,
          wizard: AdminScheduleWizardKind.edit,
        ),
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminScheduleChooseField(),
        replyMarkup: _templates.adminScheduleFieldsInlineKeyboard(
          _editFields(schedule.category ?? parsed.$1),
        ),
      );
      return true;
    }

    if (text.startsWith('/admin_sched_del_ok ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_del_ok '.length));
      if (parsed == null) {
        return true;
      }
      final selected = _flowByUserId[userId]?.adminSchedule.selected ??
          (_flowByUserId[userId]?.adminSchedule.items.length != null &&
                  parsed.$2 < (_flowByUserId[userId]?.adminSchedule.items.length ?? 0)
              ? _flowByUserId[userId]!.adminSchedule.items[parsed.$2]
              : null);
      if (selected == null) {
        await _sendAdminMessage(chatId, _templates.adminScheduleNotFound());
        return true;
      }
      final result = await _scheduleCatalogService.delete(selected);
      if (!result.isOk) {
        await _sendAdminMessage(chatId, result.message ?? _templates.adminScheduleNotFound());
        return true;
      }
      await _sendAdminMessage(
        chatId,
        _templates.adminScheduleDeleted(refreshOk: result.refreshOk),
      );
      await _openAdminScheduleList(chatId: chatId, userId: userId, category: parsed.$1);
      return true;
    }

    if (text.startsWith('/admin_sched_del_no ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_del_no '.length));
      if (parsed == null) {
        return true;
      }
      await _openAdminScheduleCard(chatId: chatId, userId: userId, index: parsed.$2);
      return true;
    }

    if (text.startsWith('/admin_sched_del ')) {
      final parsed = _parseAdminSchedRef(text.substring('/admin_sched_del '.length));
      if (parsed == null) {
        return true;
      }
      await _openAdminScheduleCard(
        chatId: chatId,
        userId: userId,
        index: parsed.$2,
        confirmingDelete: true,
      );
      return true;
    }

    if (text.startsWith('/admin_sched_field ')) {
      final field = text.substring('/admin_sched_field '.length).trim();
      final state = _flowByUserId[userId];
      if (state == null) {
        return true;
      }
      _flowByUserId[userId] = state.copyWith(
        step: _PrivateFlowStep.enteringAdminScheduleField,
        adminSchedule: state.adminSchedule.copyWith(
          field: field,
          wizard: state.adminSchedule.wizard ?? AdminScheduleWizardKind.edit,
          awaitingCoachText: false,
        ),
      );
      await _promptAdminScheduleField(chatId: chatId, userId: userId);
      return true;
    }

    if (text == '/admin_sched_skip') {
      final wizard = _flowByUserId[userId]?.adminSchedule.wizard;
      if (wizard == AdminScheduleWizardKind.edit) {
        final index = _flowByUserId[userId]?.adminSchedule.selectedIndex;
        if (index != null) {
          await _openAdminScheduleCard(chatId: chatId, userId: userId, index: index);
        }
        return true;
      }
      await _advanceAdminScheduleCreate(chatId: chatId, userId: userId);
      return true;
    }

    if (text == '/admin_sched_save') {
      final draft = _flowByUserId[userId]?.adminSchedule.draft;
      if (draft == null) {
        return true;
      }
      final result = await _scheduleCatalogService.create(draft);
      await _handleAdminScheduleWrite(
        chatId: chatId,
        userId: userId,
        result: result,
        reopenCard: false,
      );
      return true;
    }

    if (text == '/admin_sched_cancel') {
      final category = _flowByUserId[userId]?.adminSchedule.category;
      if (category == null) {
        return _openAdminScheduleRoot(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        );
      }
      await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
      return true;
    }

    if (text.startsWith('/admin_sched_tog ')) {
      final rest = text.substring('/admin_sched_tog '.length).trim();
      final parts = rest.split(':');
      if (parts.length != 3) {
        return true;
      }
      final flag = parts[0];
      final index = int.tryParse(parts[2]);
      if (index == null) {
        return true;
      }
      if (_flowByUserId[userId]?.adminSchedule.selectedIndex != index) {
        await _openAdminScheduleCard(chatId: chatId, userId: userId, index: index);
      }
      final selected = _flowByUserId[userId]?.adminSchedule.selected;
      if (selected == null || selected.training == null) {
        return true;
      }
      final training = selected.training!;
      final patch = ScheduleEventDraft(
        category: selected.category,
        includeTrainersInParticipants:
            flag == 'it' ? !training.includeTrainersInParticipants : null,
        promoRestricted: flag == 'pr' ? !training.promoRestricted : null,
      );
      final result = await _scheduleCatalogService.update(identity: selected, patch: patch);
      await _handleAdminScheduleWrite(
        chatId: chatId,
        userId: userId,
        result: result,
        reopenCard: true,
      );
      return true;
    }

    if (text.startsWith('/admin_sched_coach ')) {
      final token = text.substring('/admin_sched_coach '.length).trim();
      if (token == 'x') {
        final state = _flowByUserId[userId];
        if (state != null) {
          _flowByUserId[userId] = state.copyWith(
            adminSchedule: state.adminSchedule.copyWith(awaitingCoachText: true),
          );
        }
        await _sendAdminMessage(chatId, 'Напиши имя тренера текстом.');
        return true;
      }
      final index = int.tryParse(token);
      final names = _flowByUserId[userId]?.adminSchedule.coachNames ?? const <String>[];
      if (index == null || index < 0 || index >= names.length) {
        return true;
      }
      await _applyAdminScheduleFieldValue(chatId: chatId, userId: userId, raw: names[index]);
      return true;
    }

    if (text.startsWith('/admin_sched_bool ')) {
      final on = text.substring('/admin_sched_bool '.length).trim() == '1';
      final state = _flowByUserId[userId];
      final field = state?.adminSchedule.field;
      final category = state?.adminSchedule.category;
      if (state == null || field == null || category == null) {
        return true;
      }
      if (state.adminSchedule.wizard == AdminScheduleWizardKind.edit) {
        final selected = state.adminSchedule.selected;
        if (selected == null) {
          return true;
        }
        final patch = ScheduleEventDraft(
          category: category,
          includeTrainersInParticipants: field == 'include_trainers' ? on : null,
          promoRestricted: field == 'promo_restricted' ? on : null,
        );
        final result = await _scheduleCatalogService.update(identity: selected, patch: patch);
        await _handleAdminScheduleWrite(
          chatId: chatId,
          userId: userId,
          result: result,
          reopenCard: true,
        );
        return true;
      }
      var draft = state.adminSchedule.draft ?? ScheduleEventDraft(category: category);
      if (field == 'include_trainers') {
        draft = draft.copyWith(includeTrainersInParticipants: on);
      } else if (field == 'promo_restricted') {
        draft = draft.copyWith(promoRestricted: on);
      }
      _flowByUserId[userId] =
          state.copyWith(adminSchedule: state.adminSchedule.copyWith(draft: draft));
      await _advanceAdminScheduleCreate(chatId: chatId, userId: userId);
      return true;
    }

    if (text == '/admin_sched_back') {
      final index = _flowByUserId[userId]?.adminSchedule.selectedIndex;
      if (index != null) {
        await _openAdminScheduleCard(chatId: chatId, userId: userId, index: index);
        return true;
      }
      final category = _flowByUserId[userId]?.adminSchedule.category;
      if (category != null) {
        await _openAdminScheduleList(chatId: chatId, userId: userId, category: category);
        return true;
      }
      return _openAdminScheduleRoot(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
    }

    final step = ctx.flowState?.step;
    if (step == _PrivateFlowStep.enteringAdminScheduleField && !text.startsWith('/')) {
      await _applyAdminScheduleFieldValue(chatId: chatId, userId: userId, raw: text);
      return true;
    }

    return false;
  }
}
