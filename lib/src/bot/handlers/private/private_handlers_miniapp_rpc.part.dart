part of '../private_handlers.dart';

/// Telegram identity of the Mini App user, verified by the Go API.
final class MiniAppCaller {
  const MiniAppCaller({required this.id, this.username, this.firstName});

  final int id;
  final String? username;
  final String? firstName;
}

/// Uploads a photo into a chat and returns the message and its file id.
typedef MiniAppPhotoUpload = Future<({int messageId, String? fileId})> Function(
  int chatId,
  List<int> bytes,
  String filename,
  String? caption,
);

/// Error with a user-facing message; the bridge turns it into `{error}`.
final class MiniAppRpcException implements Exception {
  const MiniAppRpcException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'MiniAppRpcException($code): $message';
}

/// Mini App actions beyond plain booking. Multi-step chat flows (payment,
/// promo codes, BOXING CARD, reschedule, moderation) are driven by the same
/// commands the chat buttons send, so rules, admin notices and chat
/// confirmations stay identical. The bot's replies are captured and returned
/// to the app as plain text.
extension PrivateHandlersMiniAppRpc on PrivateHandlers {
  static const int _maxImageBytes = 8 * 1024 * 1024;

  Future<Map<String, Object?>> miniAppRpc(
    String method,
    MiniAppCaller caller,
    Map<String, Object?> params, {
    MiniAppPhotoUpload? upload,
  }) async {
    if (method.startsWith('admin.') && !_adminUserIds.contains(caller.id)) {
      throw const MiniAppRpcException('forbidden', 'Раздел только для админов.');
    }
    return switch (method) {
      'payment.options' => _rpcPaymentOptions(caller, params),
      'payment.choose' => _rpcPaymentChoose(caller, params),
      'payment.receipt' => _rpcPaymentReceipt(caller, params, upload),
      'payment.bonus' => _rpcBookingTap(caller, params, '/use_bonus'),
      'payment.peaks' => _rpcBookingTap(caller, params, '/use_loyalty'),
      'payment.promo' => _rpcPaymentPromo(caller, params),
      'booking.party' => _rpcBookingParty(caller, params),
      'booking.rescheduleOptions' => _rpcRescheduleOptions(caller, params),
      'booking.reschedule' => _rpcReschedule(caller, params),
      'card.overview' => _rpcCardOverview(caller),
      'card.buy' => _rpcCardBuy(caller, params, upload),
      'team.list' => _rpcTeam(),
      'admin.report' => _rpcAdminReport(caller, params),
      'admin.cards.pending' => _rpcAdminCardsPending(),
      'admin.cards.review' => _rpcAdminCardsReview(caller, params),
      'admin.peaks.grant' => _rpcAdminPeaksGrant(caller, params),
      'admin.user' => _rpcAdminUser(params),
      'admin.broadcast' => _rpcAdminBroadcast(caller, params, upload),
      'admin.schedule.list' => _rpcAdminScheduleList(params),
      'admin.schedule.save' => _rpcAdminScheduleSave(params),
      'admin.schedule.delete' => _rpcAdminScheduleDelete(params),
      'admin.bookings.list' => _rpcAdminBookingsList(params),
      'admin.bookings.create' => _rpcAdminBookingsCreate(params),
      'admin.bookings.status' => _rpcAdminBookingsStatus(params),
      'admin.bookings.archive' => _rpcAdminBookingsArchive(params),
      'admin.contact' => _rpcAdminContact(caller, params),
      _ => throw const MiniAppRpcException('unknown_method', 'Это действие пока недоступно.'),
    };
  }

  // ---------- synthetic chat input ----------

  Map<String, Object?> _miniAppMessage(MiniAppCaller caller, Map<String, Object?> content) {
    return <String, Object?>{
      'message_id': 0,
      'date': _nowProvider().toUtc().millisecondsSinceEpoch ~/ 1000,
      'chat': <String, Object?>{'id': caller.id, 'type': 'private'},
      'from': <String, Object?>{
        'id': caller.id,
        'is_bot': false,
        'first_name': caller.firstName ?? '',
        if (caller.username != null) 'username': caller.username,
      },
      ...content,
    };
  }

  /// Feeds [inputs] to the chat handler as if the user typed or tapped them,
  /// in order, and returns everything the bot answered in that chat.
  Future<List<String>> _miniAppInput(
      MiniAppCaller caller, List<Map<String, Object?>> inputs) async {
    final (_, texts) = await MiniAppCapture.run(caller.id, () async {
      for (final content in inputs) {
        await handle(<String, dynamic>{
          'update_id': 0,
          // Lets the app drive chat flows even in Mini App mode.
          '_miniapp': true,
          'message': _miniAppMessage(caller, content),
        });
      }
    });
    return texts.map(_miniAppText).whereType<String>().toList(growable: false);
  }

  Future<List<String>> _miniAppTap(MiniAppCaller caller, List<String> texts) {
    return _miniAppInput(caller, [
      for (final text in texts) <String, Object?>{'text': text},
    ]);
  }

  /// Puts the uploaded image into the user's chat with the bot and returns a
  /// photo message the payment handlers accept as proof.
  Future<Map<String, Object?>> _miniAppPhoto(
    MiniAppCaller caller,
    Map<String, Object?> params,
    MiniAppPhotoUpload? upload,
    String caption,
  ) async {
    if (upload == null) {
      throw const MiniAppRpcException('unavailable', 'Загрузка фото сейчас недоступна.');
    }
    final raw = params['image'];
    if (raw is! String || raw.isEmpty) {
      throw const MiniAppRpcException('bad_request', 'Прикрепи фото чека.');
    }
    late final List<int> bytes;
    try {
      bytes = base64Decode(raw);
    } on FormatException {
      throw const MiniAppRpcException('bad_request', 'Фото не читается. Попробуй другое.');
    }
    if (bytes.length > _maxImageBytes) {
      throw const MiniAppRpcException('too_large', 'Фото больше 8 МБ. Сожми или сделай скриншот.');
    }
    final filename = (params['filename'] as String?)?.trim();
    final sent = await upload(
      caller.id,
      bytes,
      filename == null || filename.isEmpty ? 'receipt.jpg' : filename,
      caption,
    );
    return <String, Object?>{
      'message_id': sent.messageId,
      'photo': <Object?>[
        <String, Object?>{'file_id': sent.fileId ?? 'miniapp'},
      ],
    };
  }

  Map<String, Object?> _miniAppReply(List<String> messages,
      [Map<String, Object?> extra = const {}]) {
    return <String, Object?>{
      'messages': messages,
      if (messages.isNotEmpty) 'message': messages.last,
      ...extra,
    };
  }

  // ---------- params ----------

  int _rpcInt(Map<String, Object?> params, String key) {
    final value = params[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw MiniAppRpcException('bad_request', 'Не хватает параметра $key.');
  }

  String _rpcString(Map<String, Object?> params, String key) {
    final value = params[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw MiniAppRpcException('bad_request', 'Не хватает параметра $key.');
  }

  _ActivityCategory _rpcCategory(Map<String, Object?> params) {
    return switch (params['category']) {
      'hikes' => _ActivityCategory.hikes,
      'trails' => _ActivityCategory.trails,
      _ => _ActivityCategory.trainings,
    };
  }

  Future<TrainingBooking> _rpcOwnBooking(MiniAppCaller caller, Map<String, Object?> params) async {
    final booking = await _findUserBooking(caller.id, _rpcInt(params, 'bookingId'));
    if (booking == null) {
      throw const MiniAppRpcException('not_found', 'Запись не найдена.');
    }
    return booking;
  }

  Future<Map<String, Object?>> _rpcFreshBooking(MiniAppCaller caller, int bookingId) async {
    final booking = await _findUserBooking(caller.id, bookingId);
    return <String, Object?>{if (booking != null) 'booking': _miniAppBookingJson(booking)};
  }

  // ---------- payment ----------

  Future<Map<String, Object?>> _rpcPaymentOptions(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final category = _catalogService.categoryForBooking(booking);
    final payable = _isPayableForProof(booking);
    final training = _catalogService.trainingInfoForBooking(booking);
    final promoRestricted = training?.promoRestricted ?? false;
    final price = booking.trainingPrice ?? 0;
    final outdoor = _isOutdoorCategory(category);
    final prepayPercent = outdoor ? (booking.trainingPrepayPercent ?? 50) : null;
    final groupId = booking.paymentGroupId?.trim();
    var groupCount = 1;
    var groupTotal = price;
    if (groupId != null && groupId.isNotEmpty) {
      final group = await _bookingRepository.listBookingsByPaymentGroup(groupId);
      groupCount = group.length;
      groupTotal = group.fold(0, (sum, b) => sum + (b.trainingPrice ?? 0));
    }
    final starter = payable &&
        groupCount == 1 &&
        category == _ActivityCategory.trainings &&
        !promoRestricted &&
        await _hasAnyFreeTrainingBonusAvailable(caller.id);
    final canPeaks = payable &&
        groupCount == 1 &&
        await _canOfferLoyaltySpend(userId: caller.id, booking: booking);
    final quote =
        canPeaks ? await _loyaltyQuoteForBooking(userId: caller.id, booking: booking) : null;
    return <String, Object?>{
      'booking': _miniAppBookingJson(booking),
      'payable': payable,
      'amount': groupTotal,
      'participants': groupCount,
      'prepayPercent': prepayPercent,
      'prepayAmount': prepayPercent == null ? null : (groupTotal * prepayPercent / 100).round(),
      'outdoorChoice': payable && _shouldShowOutdoorPaymentTypeChoice(booking),
      'sbpLink': MessageCopy.sbpPaymentLink,
      'starterBonus': starter,
      'peaks': <String, Object?>{
        'balance': await _loyaltyService.availableBalance(caller.id, now: _nowProvider()),
        'available': canPeaks && (quote?.peaks ?? 0) > 0,
        'spend': quote?.peaks ?? 0,
        'remainderRub': quote?.remainderRub,
        'coversFully': quote?.coversFully ?? false,
      },
      'promo': payable && groupCount == 1 && _shouldShowPromoCodeEntry(booking),
      'promoCode': booking.promoCode,
    };
  }

  String _paidCommand(TrainingBooking booking, Object? choice) {
    final outdoor = _isOutdoorCategory(_catalogService.categoryForBooking(booking));
    if (outdoor && _shouldShowOutdoorPaymentTypeChoice(booking)) {
      return choice == 'partial' ? '/paid_partial ${booking.id}' : '/paid_full ${booking.id}';
    }
    return '/paid ${booking.id}';
  }

  Future<Map<String, Object?>> _rpcPaymentChoose(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final messages = await _miniAppTap(caller, [_paidCommand(booking, params['choice'])]);
    return _miniAppReply(messages, await _rpcFreshBooking(caller, booking.id));
  }

  Future<Map<String, Object?>> _rpcPaymentReceipt(
    MiniAppCaller caller,
    Map<String, Object?> params,
    MiniAppPhotoUpload? upload,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    if (!_isPayableForProof(booking)) {
      throw const MiniAppRpcException('not_payable', 'Эта запись уже не ждёт оплаты.');
    }
    final photo = await _miniAppPhoto(
      caller,
      params,
      upload,
      'Чек к записи «${_miniAppText(booking.trainingTitle) ?? booking.trainingTitle}» — из приложения',
    );
    final messages = await _miniAppInput(caller, [
      <String, Object?>{'text': _paidCommand(booking, params['choice'])},
      photo,
    ]);
    return _miniAppReply(messages, await _rpcFreshBooking(caller, booking.id));
  }

  Future<Map<String, Object?>> _rpcBookingTap(
    MiniAppCaller caller,
    Map<String, Object?> params,
    String command,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final messages = await _miniAppTap(caller, ['$command ${booking.id}']);
    return _miniAppReply(messages, await _rpcFreshBooking(caller, booking.id));
  }

  Future<Map<String, Object?>> _rpcPaymentPromo(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final code = _rpcString(params, 'code');
    final messages = await _miniAppTap(caller, ['/enter_promo ${booking.id}', code]);
    return _miniAppReply(messages, await _rpcFreshBooking(caller, booking.id));
  }

  // ---------- booking ----------

  Future<Map<String, Object?>> _rpcBookingParty(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final training = _miniAppFindTraining(_rpcString(params, 'key'));
    if (training == null) {
      throw const MiniAppRpcException('not_found', 'Событие не найдено.');
    }
    final participants = <BookingParticipantDraft>[
      if (params['self'] == true) const BookingParticipantDraft.self(),
      for (final username in (params['telegram'] as List<Object?>? ?? const []).whereType<String>())
        if (username.trim().isNotEmpty) BookingParticipantDraft.telegram(username: username.trim()),
      for (final name in (params['guests'] as List<Object?>? ?? const []).whereType<String>())
        if (name.trim().isNotEmpty) BookingParticipantDraft.guest(name: name.trim()),
    ];
    final others = participants.where((p) => p.type != BookingParticipantType.self).length;
    if (participants.isEmpty) {
      throw const MiniAppRpcException('bad_request', 'Добавь хотя бы одного участника.');
    }
    if (others > maxManagedGuestsPerEvent) {
      throw const MiniAppRpcException(
          'too_many', 'За раз можно записать до $maxManagedGuestsPerEvent друзей.');
    }
    final isAdmin = _adminUserIds.contains(caller.id);
    final (_, texts) = await MiniAppCapture.run(caller.id, () async {
      try {
        await _createPartyBookingGroup(
          chatId: caller.id,
          userId: caller.id,
          isAdmin: isAdmin,
          flowState: const _PrivateFlowState(
            step: _PrivateFlowStep.selectingBookingCategory,
            availableTrainings: <TrainingInfo>[],
          ),
          training: training,
          participants: participants,
          username: caller.username,
        );
      } on TelegramApiException catch (error, stackTrace) {
        l.w('Mini App party booking: chat card failed for ${caller.id}: $error', stackTrace);
      }
    });
    final bookings = (await _bookingRepository.listUserBookings(caller.id, limit: 100))
        .where((b) => b.trainingKey == training.sessionKey && _miniAppIsActive(b))
        .map(_miniAppBookingJson)
        .toList(growable: false);
    return _miniAppReply(
      texts.map(_miniAppText).whereType<String>().toList(),
      <String, Object?>{'bookings': bookings},
    );
  }

  Future<List<TrainingInfo>> _rescheduleTargets(TrainingBooking booking) async {
    if (!_bookingPolicyService.canReschedule(booking)) {
      throw const MiniAppRpcException('not_allowed', 'Перенести можно только тренировку.');
    }
    final boxingCard = MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote);
    if (boxingCard && !BoxingCardLedger.canReschedule(booking, now: _nowProvider())) {
      throw MiniAppRpcException(
        'too_late',
        _miniAppText(_templates.boxingCardRescheduleTooLate()) ?? 'Перенести уже нельзя.',
      );
    }
    var trainings = _bookableItemsByCategory(_catalogService.categoryForBooking(booking))
        .where((item) => _bookingPolicyService.allowsRescheduleOnto(booking: booking, target: item))
        .toList();
    if (boxingCard) {
      trainings = trainings.where(BoxingCardLedger.isAllowedRescheduleTarget).toList();
    }
    return trainings;
  }

  Future<Map<String, Object?>> _rpcRescheduleOptions(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final targets = await _rescheduleTargets(booking);
    return <String, Object?>{
      'events': [
        for (final t in targets)
          if (t.sessionKey != booking.trainingKey) _miniAppEventJson(t),
      ],
    };
  }

  Future<Map<String, Object?>> _rpcReschedule(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final booking = await _rpcOwnBooking(caller, params);
    final key = _rpcString(params, 'key');
    await _rescheduleTargets(booking);
    final (_, texts) = await MiniAppCapture.run(caller.id, () async {
      await handle(<String, dynamic>{
        'update_id': 0,
        '_miniapp': true,
        'message': _miniAppMessage(caller, {'text': '/reschedule_booking ${booking.id}'}),
      });
      final offered = _flowByUserId[caller.id]?.availableTrainings ?? const <TrainingInfo>[];
      final index = offered.indexWhere((t) => t.sessionKey == key);
      if (index < 0) {
        _flowByUserId.remove(caller.id);
        throw const MiniAppRpcException('not_found', 'На это событие перенести нельзя.');
      }
      await handle(<String, dynamic>{
        'update_id': 0,
        '_miniapp': true,
        'message': _miniAppMessage(caller, {'text': '${index + 1}'}),
      });
    });
    final moved = (await _bookingRepository.listUserBookings(caller.id, limit: 100))
        .where((b) => b.id == booking.id)
        .map(_miniAppBookingJson)
        .firstOrNull;
    return _miniAppReply(
      texts.map(_miniAppText).whereType<String>().toList(),
      <String, Object?>{if (moved != null) 'booking': moved},
    );
  }

  // ---------- BOXING CARD ----------

  Future<Map<String, Object?>> _rpcCardOverview(MiniAppCaller caller) async {
    final now = _nowProvider();
    final membership = await _subscriptionRepository.getMembership(caller.id, now: now);
    final snapshot = await _subscriptionRepository.getUserSnapshot(caller.id, now: now);
    final active = BoxingCardLedger.isActiveBoxingCard(membership, now: now);
    final remaining = active
        ? await _boxingCardRemainingGroupCount(userId: caller.id, membership: membership)
        : null;
    final balance = await _loyaltyService.availableBalance(caller.id, now: now);
    return <String, Object?>{
      'active': active,
      'plan': membership.plan?.dbValue,
      'activeUntil': membership.activeUntil?.toUtc().toIso8601String(),
      'remaining': remaining,
      'quota': membership.plan?.groupQuota,
      'individualUsed': active ? await _isBoxingCardIndividualUsed(membership) : null,
      'pending': snapshot.latestPending == null
          ? null
          : <String, Object?>{
              'plan': snapshot.latestPending!.plan?.dbValue,
              'createdAt': snapshot.latestPending!.createdAt.toUtc().toIso8601String(),
            },
      'peaksBalance': balance,
      'sbpLink': MessageCopy.sbpPaymentLink,
      'plans': [
        for (final plan in BoxingCardPlan.values)
          <String, Object?>{
            'id': plan.dbValue,
            'name': plan.displayName,
            'price': plan.priceRub,
            'trainings': plan.groupQuota,
            'individual': plan.individualQuota,
            'peaksQuote': await _cardQuoteJson(caller.id, plan),
          },
      ],
    };
  }

  Future<Map<String, Object?>> _cardQuoteJson(int userId, BoxingCardPlan plan) async {
    final quote = await _loyaltyQuoteForCard(userId: userId, plan: plan);
    return <String, Object?>{
      'spend': quote.peaks,
      'remainderRub': quote.remainderRub,
      'coversFully': quote.coversFully,
    };
  }

  Future<Map<String, Object?>> _rpcCardBuy(
    MiniAppCaller caller,
    Map<String, Object?> params,
    MiniAppPhotoUpload? upload,
  ) async {
    final plan = switch (params['plan']) {
      'baza' => BoxingCardPlan.baza,
      'udar' => BoxingCardPlan.udar,
      _ => throw const MiniAppRpcException('bad_request', 'Выбери тариф.'),
    };
    final usePeaks = params['usePeaks'] == true;
    final quote = await _loyaltyQuoteForCard(userId: caller.id, plan: plan);
    final needsReceipt = !(usePeaks && quote.coversFully);
    final inputs = <Map<String, Object?>>[
      <String, Object?>{'text': MessageTemplates.buttonSubscribeApply},
      <String, Object?>{
        'text': plan == BoxingCardPlan.baza
            ? MessageTemplates.buttonPlanBaza
            : MessageTemplates.buttonPlanUdar,
      },
      if (usePeaks && quote.peaks > 0)
        <String, Object?>{'text': MessageTemplates.buttonSpendLoyaltyPeaks},
    ];
    if (needsReceipt) {
      inputs.add(await _miniAppPhoto(caller, params, upload, 'Чек за BOXING CARD — из приложения'));
    }
    final messages = await _miniAppInput(caller, inputs);
    return _miniAppReply(messages, await _rpcCardOverview(caller));
  }

  // ---------- team ----------

  Future<Map<String, Object?>> _rpcTeam() async {
    await _trainerDirectoryRepository.refresh();
    return <String, Object?>{
      'people': [
        for (final person in _trainerDirectoryRepository.list(limit: 60))
          <String, Object?>{
            'name': person.name,
            'link': person.link,
            'description': _miniAppText(person.description),
            'role': person.role,
            'kind': person.kind.name,
          },
      ],
    };
  }

  // ---------- admin: reports and moderation ----------

  static const Map<String, String> _reportCommands = <String, String>{
    'overview': '/analytics',
    'bookings': '/booking_analytics',
    'peaks': '/loyalty_analytics',
    'cards': '/subscription_analytics',
    'funnel': '/funnel_analytics',
    'feedback': '/feedback_analytics',
    'economic_current_week': '/economic_summary current_week',
    'economic_previous_week': '/economic_summary previous_week',
    'economic_current_month': '/economic_summary current_month',
    'economic_previous_month': '/economic_summary previous_month',
  };

  Future<Map<String, Object?>> _rpcAdminReport(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final command = _reportCommands[params['kind']];
    if (command == null) {
      throw const MiniAppRpcException('bad_request', 'Неизвестный отчёт.');
    }
    _adminsInClientMode.remove(caller.id);
    final messages = await _miniAppTap(caller, [command]);
    _flowByUserId.remove(caller.id);
    return <String, Object?>{'text': messages.join('\n\n')};
  }

  Future<Map<String, Object?>> _rpcAdminCardsPending() async {
    final pending = await _subscriptionRepository.listPendingRequests(limit: 50);
    return <String, Object?>{
      'requests': [
        for (final r in pending)
          <String, Object?>{
            'id': r.id,
            'userId': r.userId,
            'username': r.userUsername,
            'plan': r.plan?.dbValue,
            'planName': r.plan?.displayName,
            'price': r.plan?.priceRub,
            'createdAt': r.createdAt.toUtc().toIso8601String(),
            'note': _miniAppText(r.paymentNote),
            'hasProof': r.paymentProofChatId != null && r.paymentProofMessageId != null,
            'peaksSpent': await _loyaltyService.peaksSpentOnSubscription(r.id),
          },
      ],
    };
  }

  Future<Map<String, Object?>> _rpcAdminCardsReview(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final id = _rpcInt(params, 'id');
    _adminsInClientMode.remove(caller.id);
    if (params['approve'] == true) {
      final messages = await _miniAppTap(caller, ['/approve_subscription $id']);
      _flowByUserId.remove(caller.id);
      return _miniAppReply(messages);
    }
    final reason = switch (params['reason']) {
      'wrong_amount' => MessageTemplates.buttonReasonWrongAmount,
      'duplicate' => MessageTemplates.buttonReasonDuplicate,
      _ => MessageTemplates.buttonReasonNotConfirmed,
    };
    final comment = (params['comment'] as String?)?.trim();
    final messages = await _miniAppTap(caller, [
      '/reject_subscription $id',
      reason,
      if (comment == null || comment.isEmpty) MessageTemplates.buttonSkipComment else comment,
    ]);
    _flowByUserId.remove(caller.id);
    return _miniAppReply(messages);
  }

  Future<int?> _rpcResolveUser(String raw) async {
    final asId = int.tryParse(raw.trim());
    if (asId != null) {
      return asId;
    }
    final normalized = normalizeTelegramUsername(raw);
    if (normalized == null) {
      return null;
    }
    final found = await _bookingRepository.adminSearchBookingsByUsername(normalized, limit: 20);
    for (final b in found) {
      final label = normalizeTelegramUsername(b.participantUsername ?? b.userUsername);
      if (label == normalized) {
        return b.participantUserId ?? b.userId;
      }
    }
    return _conversationLogRepository.resolveUserIdByUsername(normalized);
  }

  Future<Map<String, Object?>> _rpcAdminPeaksGrant(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final userId = await _rpcResolveUser(_rpcString(params, 'user'));
    if (userId == null || userId <= 0) {
      throw const MiniAppRpcException(
          'not_found', 'Пользователь не найден. Нужен @username из бота.');
    }
    final amount = _rpcInt(params, 'amount');
    final result = amount > 0
        ? await _loyaltyService.adminGrant(userId: userId, amount: amount, now: _nowProvider())
        : await _loyaltyService.adminDebit(userId: userId, amount: -amount, now: _nowProvider());
    if (!result.applied) {
      throw const MiniAppRpcException(
        'not_applied',
        'Не получилось. Сумма кратна 10, списать больше баланса нельзя.',
      );
    }
    return <String, Object?>{
      'userId': userId,
      'amount': result.amount,
      'balance': result.account.remaining,
      'message': amount > 0
          ? 'Начислено ${result.amount} ⛰️. Баланс: ${result.account.remaining}.'
          : 'Списано ${result.amount} ⛰️. Баланс: ${result.account.remaining}.',
    };
  }

  Future<Map<String, Object?>> _rpcAdminUser(Map<String, Object?> params) async {
    final query = _rpcString(params, 'user');
    final userId = await _rpcResolveUser(query);
    final normalized = normalizeTelegramUsername(query);
    final bookings = <TrainingBooking>[
      if (userId != null && userId > 0)
        ...await _bookingRepository.listUserBookings(userId, limit: 30),
      if (normalized != null)
        ...await _bookingRepository.adminSearchBookingsByUsername(normalized, limit: 30),
    ];
    final seen = <int>{};
    final unique = bookings.where((b) => seen.add(b.id)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final now = _nowProvider();
    final membership =
        userId == null ? null : await _subscriptionRepository.getMembership(userId, now: now);
    return <String, Object?>{
      'userId': userId,
      'username': normalized,
      'peaks': userId == null ? null : await _loyaltyService.availableBalance(userId, now: now),
      'card': membership == null || membership.plan == null
          ? null
          : <String, Object?>{
              'plan': membership.plan!.displayName,
              'activeUntil': membership.activeUntil?.toUtc().toIso8601String(),
              'active': BoxingCardLedger.isActiveBoxingCard(membership, now: now),
            },
      'bookings': await _miniAppAdminBookingsJson(unique.take(30).toList()),
    };
  }

  Future<Map<String, Object?>> _rpcAdminBroadcast(
    MiniAppCaller caller,
    Map<String, Object?> params,
    MiniAppPhotoUpload? upload,
  ) async {
    final text = (params['text'] as String?)?.trim() ?? '';
    final hasImage = params['image'] is String && (params['image'] as String).isNotEmpty;
    if (text.isEmpty && !hasImage) {
      throw const MiniAppRpcException('bad_request', 'Нужен текст или фото.');
    }
    late final BroadcastContent content;
    if (hasImage) {
      if (upload == null) {
        throw const MiniAppRpcException('unavailable', 'Загрузка фото сейчас недоступна.');
      }
      // The photo lands in the admin's chat first (with the text as caption)
      // and is copied from there, exactly like a chat broadcast with media.
      final bytes = base64Decode(params['image']! as String);
      final sent = await upload(caller.id, bytes, 'broadcast.jpg', text.isEmpty ? null : text);
      content = BroadcastContent.media([
        BroadcastMessageRef(fromChatId: caller.id, messageId: sent.messageId),
      ]);
    } else {
      content = BroadcastContent.text(escapeHtml(text));
    }
    switch (params['audience']) {
      case 'group':
        final ok = await _broadcastService.broadcastToGroup(content);
        return <String, Object?>{
          'message': ok ? 'Отправлено в группу.' : 'В группу отправить не получилось.',
        };
      case 'outdoor':
        final result = await _broadcastService.broadcastToUsers(
          content,
          audience: BroadcastAudience.outdoorPlus,
        );
        return _broadcastReply(result);
      case 'all':
        return _broadcastReply(await _broadcastService.broadcastToUsersAndGroup(content));
      default:
        return _broadcastReply(await _broadcastService.broadcastToUsers(content));
    }
  }

  Map<String, Object?> _broadcastReply(BroadcastResult result) {
    return <String, Object?>{
      'sent': result.sent,
      'failed': result.failed,
      'total': result.total,
      'message': 'Доставлено ${result.sent} из ${result.total}'
          '${result.failed > 0 ? ', не дошло ${result.failed}' : ''}.',
    };
  }

  // ---------- admin: schedule ----------

  Map<String, Object?> _catalogItemJson(ScheduleCatalogItem item) {
    final t = item.training;
    final o = item.outdoor;
    return <String, Object?>{
      'row': item.sheetRow,
      'category': item.category.name,
      'title': item.title,
      'startsAt': _miniAppInstant(item.sortAt),
      'fields': <String, Object?>{
        'title': item.title,
        if (t != null) ...<String, Object?>{
          'date': DateFormat('dd.MM.yyyy').format(t.startsAt),
          'time': DateFormat('HH:mm').format(t.startsAt),
          'location': t.location,
          'map': t.locationUrl ?? '',
          'coach': t.coach ?? '',
          'price': t.price?.toString() ?? '',
          'limit': t.participantsLimit?.toString() ?? '',
          'notes': _miniAppText(t.notes) ?? '',
        },
        if (o != null) ...<String, Object?>{
          'date_from': DateFormat('dd.MM.yyyy').format(o.dateFrom),
          'date_to': DateFormat('dd.MM.yyyy').format(o.dateTo),
          'location': o.location ?? '',
          'price': o.price?.toString() ?? '',
          'limit': o.participantsLimit?.toString() ?? '',
          'prepay': o.prepayPercent.toString(),
          'description': _miniAppText(o.description) ?? '',
          'equipment': _miniAppText(o.equipment) ?? '',
          'itinerary': _miniAppText(o.itinerary) ?? '',
        },
      },
    };
  }

  Future<Map<String, Object?>> _rpcAdminScheduleList(Map<String, Object?> params) async {
    try {
      final items = await _scheduleCatalogService.listItems(_rpcCategory(params));
      return <String, Object?>{'items': items.map(_catalogItemJson).toList(growable: false)};
    } on ScheduleCatalogFailure catch (error) {
      throw MiniAppRpcException('unavailable', _scheduleFailureText(error.code));
    }
  }

  String _scheduleFailureText(ScheduleCatalogErrorCode? code) {
    return switch (code) {
      ScheduleCatalogErrorCode.staticSource =>
        'Расписание берётся не из таблицы — править можно только в Google Sheets.',
      ScheduleCatalogErrorCode.writeDisabled =>
        'Запись в таблицу выключена (GOOGLE_SHEETS_WRITE_ENABLED).',
      _ => 'Таблица не ответила. Попробуй ещё раз.',
    };
  }

  Future<ScheduleCatalogItem> _catalogItem(Map<String, Object?> params) async {
    final row = _rpcInt(params, 'row');
    final items = await _scheduleCatalogService.listItems(_rpcCategory(params));
    final item = items.where((i) => i.sheetRow == row).firstOrNull;
    if (item == null) {
      throw const MiniAppRpcException('not_found', 'Событие в таблице не найдено. Обнови список.');
    }
    return item;
  }

  Future<Map<String, Object?>> _rpcAdminScheduleSave(Map<String, Object?> params) async {
    final category = _rpcCategory(params);
    final fields = (params['fields'] as Map<String, Object?>?) ?? const {};
    final isCreate = params['row'] == null;
    final required = category == _ActivityCategory.trainings
        ? const ['title', 'date', 'time', 'location']
        : const ['title', 'date_from', 'description'];
    final errors = <String, String>{};
    var draft = ScheduleEventDraft(category: category);
    for (final entry in fields.entries) {
      final raw = entry.value?.toString() ?? '';
      if (!isCreate && raw.isEmpty && required.contains(entry.key)) {
        continue;
      }
      final error = _scheduleCatalogService.validateField(
        category: category,
        field: entry.key,
        raw: raw,
      );
      if (error != null) {
        errors[entry.key] = error;
        continue;
      }
      draft = _scheduleCatalogService.applyField(draft: draft, field: entry.key, raw: raw);
    }
    if (isCreate) {
      for (final field in required) {
        final raw = fields[field]?.toString().trim() ?? '';
        if (raw.isEmpty) {
          errors.putIfAbsent(field, () => 'Обязательное поле.');
        }
      }
    }
    if (errors.isNotEmpty) {
      return <String, Object?>{'errors': errors};
    }
    try {
      final result = isCreate
          ? await _scheduleCatalogService.create(draft)
          : await _scheduleCatalogService.update(
              identity: await _catalogItem(params), patch: draft);
      if (!result.isOk) {
        throw MiniAppRpcException('failed', result.message ?? _scheduleFailureText(result.error));
      }
      return <String, Object?>{
        if (result.item != null) 'item': _catalogItemJson(result.item!),
        'message': isCreate ? 'Событие добавлено в таблицу.' : 'Изменения сохранены.',
        'refreshOk': result.refreshOk,
      };
    } on ScheduleCatalogFailure catch (error) {
      throw MiniAppRpcException('unavailable', _scheduleFailureText(error.code));
    }
  }

  Future<Map<String, Object?>> _rpcAdminScheduleDelete(Map<String, Object?> params) async {
    try {
      final result = await _scheduleCatalogService.delete(await _catalogItem(params));
      if (!result.isOk) {
        throw MiniAppRpcException('failed', result.message ?? _scheduleFailureText(result.error));
      }
      return const <String, Object?>{'message': 'Событие удалено из таблицы.'};
    } on ScheduleCatalogFailure catch (error) {
      throw MiniAppRpcException('unavailable', _scheduleFailureText(error.code));
    }
  }

  // ---------- admin: bookings ----------

  /// @username without the @, original letter case kept.
  String? _usernameKeepingCase(String? username) {
    final trimmed = username?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final raw = trimmed.startsWith('@') ? trimmed.substring(1).trim() : trimmed;
    return raw.isEmpty ? null : raw;
  }

  /// Telegram user a booking belongs to (null for guests without Telegram)
  /// and their @username, looked up when the booking row has none.
  Future<({int? userId, String? username})> _bookingPerson(TrainingBooking booking) async {
    if (booking.participantType == BookingParticipantType.guest) {
      return (userId: null, username: null);
    }
    final userId = booking.participantUserId ?? booking.userId;
    var username = _usernameKeepingCase(
      booking.participantType == BookingParticipantType.telegram
          ? booking.participantUsername
          : booking.userUsername,
    );
    if (username == null && userId > 0) {
      username = await _conversationLogRepository.usernameForUserId(userId);
    }
    return (userId: userId > 0 ? userId : null, username: username);
  }

  Future<Map<String, Object?>> _miniAppAdminBookingJson(TrainingBooking booking) async {
    final person = await _bookingPerson(booking);
    final label = switch (booking.participantType) {
      BookingParticipantType.guest => '${booking.participantDisplayLabel} · гость',
      _ when person.username != null => '@${person.username}',
      _ => 'Без username',
    };
    return <String, Object?>{
      ..._miniAppBookingJson(booking),
      'userId': booking.userId,
      'manager': _usernameKeepingCase(booking.userUsername),
      'participant': label,
      'contactUserId': person.userId,
      'contactUsername': person.username,
      'promoCode': booking.promoCode,
      'paymentNote': _miniAppText(booking.paymentNote),
      'createdAt': booking.createdAt.toUtc().toIso8601String(),
    };
  }

  Future<List<Map<String, Object?>>> _miniAppAdminBookingsJson(
      List<TrainingBooking> bookings) async {
    return [for (final b in bookings) await _miniAppAdminBookingJson(b)];
  }

  Future<Map<String, Object?>> _rpcAdminBookingsList(Map<String, Object?> params) async {
    final bookings = await _bookingRepository.adminListBookings(
      category: _rpcCategory(params),
      archived: params['archived'] == true,
      limit: 300,
    );
    return <String, Object?>{'bookings': await _miniAppAdminBookingsJson(bookings)};
  }

  /// Same optional notice the chat admin flow offers after each change.
  Future<String?> _maybeNotifyMember(
    Map<String, Object?> params,
    _AdminClientNotificationAction action,
    TrainingBooking booking,
  ) async {
    if (params['notify'] != true) {
      return null;
    }
    final failure = await _notifyUserAboutAdminBookingMutation(action: action, booking: booking);
    return failure == null ? 'Участник уведомлён.' : 'Уведомить не удалось: $failure';
  }

  /// Sends the admin a tap-to-open link to a member's Telegram profile
  /// (works without @username), then the app opens the bot chat.
  Future<Map<String, Object?>> _rpcAdminContact(
    MiniAppCaller caller,
    Map<String, Object?> params,
  ) async {
    final userId = _rpcInt(params, 'userId');
    final context = (params['context'] as String?)?.trim();
    await _sendAdminMessage(
      caller.id,
      _templates.adminMemberContact(userId: userId, context: context),
    );
    return const <String, Object?>{'message': 'Ссылка на участника — в чате с ботом.'};
  }

  BookingStatus _rpcStatus(Map<String, Object?> params) {
    final raw = _rpcString(params, 'status');
    final status = BookingStatus.values.where((s) => s.dbValue == raw).firstOrNull;
    if (status == null) {
      throw const MiniAppRpcException('bad_request', 'Неизвестный статус.');
    }
    return status;
  }

  Future<Map<String, Object?>> _rpcAdminBookingsCreate(Map<String, Object?> params) async {
    final training = _miniAppFindTraining(_rpcString(params, 'key'));
    if (training == null) {
      throw const MiniAppRpcException('not_found', 'Событие не найдено.');
    }
    final username = normalizeTelegramUsername(_rpcString(params, 'username'));
    if (username == null) {
      throw const MiniAppRpcException('bad_request', 'Нужен @username участника.');
    }
    try {
      final booking = await _bookingRepository.adminCreateBooking(
        userId: await _rpcResolveUser(username) ?? 0,
        userUsername: username,
        training: training,
        status: _rpcStatus(params),
      );
      final notice = await _maybeNotifyMember(
        params,
        _AdminClientNotificationAction.bookingCreated,
        booking,
      );
      return <String, Object?>{
        'booking': await _miniAppAdminBookingJson(booking),
        'message': ['Запись создана.', if (notice != null) notice].join(' '),
      };
    } on Object catch (error) {
      if (error is MiniAppRpcException) {
        rethrow;
      }
      throw const MiniAppRpcException('conflict', 'Этот участник уже записан на событие.');
    }
  }

  Future<Map<String, Object?>> _rpcAdminBookingsStatus(Map<String, Object?> params) async {
    final updated = await _bookingRepository.adminUpdateBooking(
      bookingId: _rpcInt(params, 'id'),
      status: _rpcStatus(params),
    );
    if (updated == null) {
      throw const MiniAppRpcException('not_found', 'Запись не найдена.');
    }
    final notice = await _maybeNotifyMember(
      params,
      _AdminClientNotificationAction.bookingStatusUpdated,
      updated,
    );
    return <String, Object?>{
      'booking': await _miniAppAdminBookingJson(updated),
      'message': [
        'Статус: ${MessageFormatters.statusLabel(updated.status)}.',
        if (notice != null) notice
      ].join(' '),
    };
  }

  Future<Map<String, Object?>> _rpcAdminBookingsArchive(Map<String, Object?> params) async {
    final archived = await _bookingRepository.adminArchiveBooking(_rpcInt(params, 'id'));
    if (archived == null) {
      throw const MiniAppRpcException('not_found', 'Запись не найдена.');
    }
    final notice = await _maybeNotifyMember(
      params,
      _AdminClientNotificationAction.bookingDeleted,
      archived,
    );
    return <String, Object?>{
      'message': ['Запись убрана в архив.', if (notice != null) notice].join(' ')
    };
  }
}
