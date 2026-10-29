part of '../private_handlers.dart';

/// Mini App admin section: payment review and attendance run through the same
/// helpers as the chat admin buttons, so user cards, admin chat notes, ⛰️ sync
/// and group capacity posts stay identical. The API checks admin rights; the
/// bot re-checks [PrivateHandlers._adminUserIds] before any write.
extension PrivateHandlersMiniAppAdmin on PrivateHandlers {
  static const Duration _miniAppAttendanceLookback = Duration(days: 7);
  static const Map<String, Object?> _forbidden = <String, Object?>{'outcome': 'forbidden'};

  Future<Map<String, Object?>> miniAppAdminPayments() async {
    final queue = await _paymentReviewService.queue();
    final items = <Map<String, Object?>>[];
    for (final booking in queue) {
      final username = normalizeTelegramUsername(booking.userUsername) ??
          await _conversationLogRepository.usernameForUserId(booking.managerUserId);
      items.add(_miniAppPaymentJson(booking, await _groupBookingsFor(booking), username));
    }
    return <String, Object?>{'payments': items};
  }

  Future<Map<String, Object?>> miniAppAdminReviewPayment({
    required int adminUserId,
    required String? adminUsername,
    required int bookingId,
    required String decision,
  }) async {
    if (!_adminUserIds.contains(adminUserId)) {
      return _forbidden;
    }
    final status = switch (decision) {
      'approve' => BookingStatus.paid,
      'approve_partial' => BookingStatus.partialPaid,
      'reject' => BookingStatus.paymentRejected,
      _ => throw const FormatException('decision must be approve, approve_partial or reject'),
    };
    final result = await _applyPaymentReview(
      bookingId: bookingId,
      status: status,
      moderatorUserId: adminUserId,
      moderatorUsername: adminUsername,
    );
    final booking = result.booking;
    return switch (result.outcome) {
      PaymentReviewOutcome.success when booking != null => <String, Object?>{
          'outcome': 'reviewed',
          'bookingId': booking.id,
          'status': booking.status.dbValue,
        },
      PaymentReviewOutcome.invalidStatus => const <String, Object?>{'outcome': 'already_reviewed'},
      _ => const <String, Object?>{'outcome': 'not_found'},
    };
  }

  /// Copies the receipt photo into the admin's chat with the bot: Mini App
  /// cannot read Telegram media, the chat already shows it.
  Future<Map<String, Object?>> miniAppAdminSendProof({
    required int adminUserId,
    required int bookingId,
  }) async {
    if (!_adminUserIds.contains(adminUserId)) {
      return _forbidden;
    }
    final booking = await _bookingRepository.findBookingById(bookingId);
    final proofChatId = booking?.paymentProofChatId;
    final proofMessageId = booking?.paymentProofMessageId;
    if (booking == null || proofChatId == null || proofMessageId == null) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    try {
      await _sender.copyMessage(
        adminUserId,
        fromChatId: proofChatId,
        messageId: proofMessageId,
        disableNotification: false,
      );
    } on TelegramApiException catch (error, stackTrace) {
      l.w('Mini App: failed to copy payment proof ${booking.id}: $error', stackTrace);
      return const <String, Object?>{'outcome': 'unavailable'};
    }
    return const <String, Object?>{'outcome': 'sent'};
  }

  /// Upcoming catalog events plus trainings of the last week (attendance).
  Future<Map<String, Object?>> miniAppAdminSessions() async {
    final now = _nowProvider();
    final sessions = <String, TrainingInfo>{
      for (final training in _miniAppCatalogItems()) training.sessionKey: training,
    };
    final recent = await _bookingRepository.listBookingsStartedBetween(
      startsFromInclusive: now.subtract(_miniAppAttendanceLookback),
      startsToInclusive: now,
    );
    for (final booking in recent) {
      sessions.putIfAbsent(booking.trainingKey, () => _trainingInfoFromBooking(booking));
    }
    final bookings = await _bookingRepository.listByTrainingKeys(
      sessions.keys.toSet(),
      limit: 5000,
    );
    final byKey = <String, List<TrainingBooking>>{};
    for (final booking in bookings) {
      byKey.putIfAbsent(booking.trainingKey, () => <TrainingBooking>[]).add(booking);
    }
    final items = sessions.entries.map((entry) {
      final roster = byKey[entry.key] ?? const <TrainingBooking>[];
      return _miniAppSessionJson(entry.key, entry.value, roster: roster, now: now);
    }).toList(growable: false)
      ..sort((a, b) => (a['startsAt']! as String).compareTo(b['startsAt']! as String));
    return <String, Object?>{'sessions': items};
  }

  Future<Map<String, Object?>> miniAppAdminParticipants(String sessionKey) async {
    final roster = await _bookingRepository.listByTrainingKeys(<String>{sessionKey}, limit: 500);
    final training = _miniAppFindTraining(sessionKey) ??
        (roster.isEmpty ? null : _trainingInfoFromBooking(roster.first));
    if (training == null) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    final now = _nowProvider();
    return <String, Object?>{
      'outcome': 'ok',
      'session': _miniAppSessionJson(sessionKey, training, roster: roster, now: now),
      'participants': roster
          .map((booking) => _miniAppParticipantJson(booking, now: now))
          .toList(growable: false),
    };
  }

  Future<Map<String, Object?>> miniAppAdminMarkAttendance({
    required int adminUserId,
    required int bookingId,
    required String attendance,
  }) async {
    if (!_adminUserIds.contains(adminUserId)) {
      return _forbidden;
    }
    final mark = switch (attendance) {
      'attended' => BookingAttendance.attended,
      'absent' => BookingAttendance.absent,
      _ => throw const FormatException('attendance must be attended or absent'),
    };
    final result = await _applyAttendance(bookingId: bookingId, attendance: mark);
    final reason = result.notAllowedReason;
    if (reason != null) {
      return <String, Object?>{'outcome': 'not_allowed', 'message': reason};
    }
    final booking = result.booking;
    if (booking == null) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    return <String, Object?>{
      'outcome': 'marked',
      'peaksDelta': result.peaksDelta,
      'participant': _miniAppParticipantJson(booking, now: _nowProvider()),
    };
  }

  Map<String, Object?> _miniAppSessionJson(
    String key,
    TrainingInfo training, {
    required List<TrainingBooking> roster,
    required DateTime now,
  }) {
    final attendanceOpen =
        training.category == ActivityCategory.trainings && !training.startsAt.isAfter(now);
    return <String, Object?>{
      'key': key,
      'category': training.category.name,
      'title': training.title,
      'startsAt': _miniAppInstant(training.startsAt),
      'location': training.location,
      'limit': training.participantsLimit,
      'participants': roster.length,
      'attendanceOpen': attendanceOpen,
      'unmarked': attendanceOpen
          ? roster
              .where(
                (booking) =>
                    booking.attendance == null &&
                    PrivateHandlersDispatchAdminAttendance._isAttendanceMarkable(booking),
              )
              .length
          : 0,
    };
  }

  Map<String, Object?> _miniAppParticipantJson(TrainingBooking booking, {required DateTime now}) {
    final canMark = _catalogService.categoryForBooking(booking) == ActivityCategory.trainings &&
        !booking.startsAt.isAfter(now) &&
        PrivateHandlersDispatchAdminAttendance._isAttendanceMarkable(booking);
    return <String, Object?>{
      'bookingId': booking.id,
      'name': _miniAppPersonLabel(booking),
      'guest': booking.participantType == BookingParticipantType.guest,
      'managedBy': booking.isManagedForOther
          ? _miniAppUserLabel(booking.userUsername, booking.managerUserId)
          : null,
      'status': booking.status.dbValue,
      'boxingCard': MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote),
      'attendance': booking.attendance?.dbValue,
      'canMark': canMark,
    };
  }

  Map<String, Object?> _miniAppPaymentJson(
    TrainingBooking booking,
    List<TrainingBooking> group,
    String? payerUsername,
  ) {
    final note = booking.paymentNote ?? '';
    final partial = note.startsWith(PrivateHandlers._paymentChoicePartialMarker);
    final full = note.startsWith(PrivateHandlers._paymentChoiceFullMarker);
    final comment = (partial
            ? note.substring(PrivateHandlers._paymentChoicePartialMarker.length)
            : full
                ? note.substring(PrivateHandlers._paymentChoiceFullMarker.length)
                : note)
        .trim();
    final showMembers = group.length > 1 || booking.isManagedForOther;
    return <String, Object?>{
      'id': booking.id,
      'key': booking.trainingKey,
      'category': _catalogService.categoryForBooking(booking).name,
      'title': booking.trainingTitle,
      'startsAt': _miniAppInstant(booking.startsAt),
      'location': booking.location,
      'price': booking.trainingPrice,
      'prepayPercent': booking.trainingPrepayPercent,
      'total': group.fold<int>(0, (sum, item) => sum + (item.trainingPrice ?? 0)),
      'paymentType': partial
          ? 'partial'
          : full
              ? 'full'
              : null,
      'comment': comment.isEmpty ? null : comment,
      'promoCode': booking.promoCode,
      'organizer': <String, Object?>{
        'userId': booking.managerUserId,
        'username': payerUsername,
        'name': payerUsername == null
            ? _miniAppUserLabel(booking.userUsername, booking.managerUserId)
            : '@$payerUsername',
      },
      'participants':
          showMembers ? group.map(_miniAppPersonLabel).toList(growable: false) : const <String>[],
      'hasProof': booking.paymentProofChatId != null && booking.paymentProofMessageId != null,
    };
  }

  String _miniAppPersonLabel(TrainingBooking booking) {
    return switch (booking.participantType) {
      BookingParticipantType.self => _miniAppUserLabel(booking.userUsername, booking.managerUserId),
      _ => booking.participantDisplayLabel,
    };
  }

  String _miniAppUserLabel(String? username, int userId) {
    final normalized = username?.trim().replaceFirst('@', '');
    return normalized == null || normalized.isEmpty ? 'id $userId' : '@$normalized';
  }
}
