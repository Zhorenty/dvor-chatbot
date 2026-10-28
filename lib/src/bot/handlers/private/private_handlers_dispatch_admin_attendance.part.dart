part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminAttendance on PrivateHandlers {
  static const Duration _attendanceLookback = Duration(days: 7);

  Future<bool> _dispatchAdminAttendanceCommands(PrivateRequestContext ctx) async {
    final text = ctx.text;
    final userId = ctx.userId;
    if (text == null || userId == null || !ctx.canRunAdminAction) {
      return false;
    }

    if (text == MessageTemplates.buttonAttendance || text.startsWith('/attendance')) {
      await _openAttendanceSessionList(chatId: ctx.chatId, userId: userId);
      return true;
    }

    if (text.startsWith('/attend ') || text.startsWith('/absent ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final attendance =
          text.startsWith('/attend ') ? BookingAttendance.attended : BookingAttendance.absent;
      await _markAttendance(
        chatId: ctx.chatId,
        userId: userId,
        bookingId: bookingId,
        attendance: attendance,
      );
      return true;
    }

    final flowState = ctx.flowState;
    if (flowState?.step == _PrivateFlowStep.selectingAttendanceSession) {
      final index = _updateRouter.parseTrainingSelectionIndex(text);
      if (index == null) {
        return false;
      }
      final sessions = flowState!.availableTrainings;
      if (index < 1 || index > sessions.length) {
        await _openAttendanceSessionList(chatId: ctx.chatId, userId: userId);
        return true;
      }
      await _openAttendanceRoster(
        chatId: ctx.chatId,
        userId: userId,
        session: sessions[index - 1],
        bookings: flowState.availableBookings,
      );
      return true;
    }

    return false;
  }

  Future<void> _openAttendanceSessionList({
    required int chatId,
    required int userId,
  }) async {
    final now = _nowProvider();
    final loaded = await _bookingRepository.listBookingsStartedBetween(
      startsFromInclusive: now.subtract(_attendanceLookback),
      startsToInclusive: now,
      limit: 500,
    );
    final bookings = loaded
        .where(
          (booking) => _catalogService.categoryForBooking(booking) == ActivityCategory.trainings,
        )
        .toList(growable: false);
    final sessions = <TrainingInfo>[];
    final grouped = <String, List<TrainingBooking>>{};
    for (final booking in bookings) {
      final bucket = grouped.putIfAbsent(booking.trainingKey, () {
        sessions.add(
          TrainingInfo(
            title: booking.trainingTitle,
            startsAt: booking.startsAt,
            location: booking.location,
            locationUrl: booking.locationUrl,
            notes: booking.trainingKey,
          ),
        );
        return <TrainingBooking>[];
      });
      bucket.add(booking);
    }
    final visibleSessions = sessions.take(12).toList(growable: false);
    final visibleKeys = visibleSessions.map((session) => session.notes).whereType<String>().toSet();
    final visibleBookings = bookings
        .where((booking) => visibleKeys.contains(booking.trainingKey))
        .toList(growable: false);
    final unmarkedByKey = <String, int>{};
    for (final booking in visibleBookings) {
      if (booking.attendance != null) {
        continue;
      }
      unmarkedByKey[booking.trainingKey] = (unmarkedByKey[booking.trainingKey] ?? 0) + 1;
    }
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingAttendanceSession,
      availableTrainings: visibleSessions,
      availableBookings: visibleBookings,
    );
    await _sendAdminMessage(
      chatId,
      _templates.attendanceSessionList(
        sessions: visibleSessions,
        unmarkedByKey: unmarkedByKey,
      ),
      replyMarkup: visibleSessions.isEmpty
          ? _templates.privateMenuKeyboard(isAdmin: true)
          : _templates.bookingSelectionKeyboard(visibleSessions),
    );
  }

  Future<void> _openAttendanceRoster({
    required int chatId,
    required int userId,
    required TrainingInfo session,
    required List<TrainingBooking> bookings,
  }) async {
    final key = session.notes ?? '';
    final roster = bookings.where((booking) => booking.trainingKey == key).toList(growable: false);
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.viewingAttendanceRoster,
      availableTrainings: <TrainingInfo>[session],
      availableBookings: roster,
      adminCreateTraining: session,
    );
    await _sendAdminMessage(
      chatId,
      _templates.attendanceRoster(session, roster),
      buttonRows: _templates.attendanceRosterButtons(roster),
    );
    await _sendAdminMessage(
      chatId,
      _templates.paymentCardNavHint(),
      replyMarkup: _templates.simpleNavigationKeyboard(),
    );
  }

  Future<void> _markAttendance({
    required int chatId,
    required int userId,
    required int bookingId,
    required BookingAttendance attendance,
  }) async {
    final result = await _applyAttendance(bookingId: bookingId, attendance: attendance);
    final updated = result.booking;
    if (result.notAllowedReason != null) {
      await _sendAdminMessage(chatId, _templates.attendanceNotAllowed(result.notAllowedReason!));
      return;
    }
    if (updated == null) {
      await _sendAdminMessage(chatId, _templates.bookingNotFound(bookingId));
      return;
    }
    await _sendAdminMessage(
      chatId,
      _templates.attendanceMarkedAdmin(
        booking: updated,
        attendance: attendance,
        peaksSyncFailed: result.peaksSyncFailed,
        peaksDelta: result.peaksDelta,
      ),
    );
    final flow = _flowByUserId[userId];
    final session = flow?.adminCreateTraining;
    if (flow?.step == _PrivateFlowStep.viewingAttendanceRoster &&
        session != null &&
        session.notes == updated.trainingKey) {
      final fresh = await _bookingRepository.listByTrainingKeys(<String>{updated.trainingKey});
      final roster = fresh.where((item) {
        return item.status == BookingStatus.paid ||
            item.status == BookingStatus.freeTraining ||
            item.status == BookingStatus.partialPaid;
      }).toList(growable: false);
      await _openAttendanceRoster(
        chatId: chatId,
        userId: userId,
        session: session,
        bookings: roster,
      );
    }
  }

  static bool _isAttendanceMarkable(TrainingBooking booking) {
    return booking.status == BookingStatus.paid ||
        booking.status == BookingStatus.freeTraining ||
        booking.status == BookingStatus.partialPaid;
  }

  /// Attendance rules, ⛰️ sync and user notice shared by the chat roster and
  /// the Mini App admin section. The caller answers the admin.
  Future<_AttendanceMarkResult> _applyAttendance({
    required int bookingId,
    required BookingAttendance attendance,
  }) async {
    final booking = await _bookingRepository.findBookingById(bookingId);
    if (booking == null) {
      return const _AttendanceMarkResult();
    }
    if (_catalogService.categoryForBooking(booking) != ActivityCategory.trainings) {
      return const _AttendanceMarkResult(notAllowedReason: 'Явка отмечается по тренировкам.');
    }
    if (!_isAttendanceMarkable(booking)) {
      return const _AttendanceMarkResult(notAllowedReason: 'Эту запись уже нельзя отметить.');
    }
    final now = _nowProvider();
    if (booking.startsAt.isAfter(now)) {
      return const _AttendanceMarkResult(notAllowedReason: 'Отметить явку можно после старта.');
    }
    final updated = await _bookingRepository.markAttendance(
      bookingId: booking.id,
      attendance: attendance,
    );
    if (updated == null) {
      return const _AttendanceMarkResult();
    }
    final sync = await _loyaltyService.syncTrainingPeaks(
      booking: updated,
      now: now,
      isTraining: true,
    );
    await _notifyAttendance(
      booking: updated,
      attendance: attendance,
      peaksDelta: sync.appliedDelta,
      loyaltyRemaining: sync.remaining,
    );
    return _AttendanceMarkResult(
      booking: updated,
      peaksDelta: sync.appliedDelta,
      peaksSyncFailed: !sync.applied && sync.requested != 0,
    );
  }

  Future<void> _notifyAttendance({
    required TrainingBooking booking,
    required BookingAttendance attendance,
    required int peaksDelta,
    required int loyaltyRemaining,
  }) async {
    final text = _templates.attendanceMarkedForUser(
      booking: booking,
      attendance: attendance,
      peaksDelta: peaksDelta,
      loyaltyRemaining: loyaltyRemaining,
    );
    final notifyUserId = booking.participantType == BookingParticipantType.guest
        ? booking.managerUserId
        : (booking.participantUserId ?? booking.userId);
    try {
      await sendBotHtml(_sender, notifyUserId, text);
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify $notifyUserId about attendance ${booking.id}: $error', stackTrace);
    }
    if (peaksDelta != 0 && notifyUserId != booking.userId) {
      try {
        await sendBotHtml(_sender, booking.userId, text);
      } on Object catch (error, stackTrace) {
        l.w(
          'Failed to notify payer ${booking.userId} about attendance ${booking.id}: $error',
          stackTrace,
        );
      }
    }
  }
}

/// Booking is null when it was not found; [notAllowedReason] is admin copy.
final class _AttendanceMarkResult {
  const _AttendanceMarkResult({
    this.booking,
    this.notAllowedReason,
    this.peaksDelta = 0,
    this.peaksSyncFailed = false,
  });

  final TrainingBooking? booking;
  final String? notAllowedReason;
  final int peaksDelta;
  final bool peaksSyncFailed;
}
