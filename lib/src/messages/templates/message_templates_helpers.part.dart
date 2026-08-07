part of '../message_templates.dart';

extension MessageTemplatesHelpers on MessageTemplates {
  String _statusLabel(BookingStatus status, {TrainingBooking? booking}) {
    if (booking != null) {
      return MessageFormatters.bookingStatusLabel(booking);
    }
    return MessageFormatters.statusLabel(status);
  }

  String _participantStatusLabel(TrainingBooking booking) {
    return MessageFormatters.participantStatusLabel(booking);
  }

  String _userTag(TrainingBooking booking) {
    return MessageFormatters.userTag(booking);
  }

  String _userTagById(int userId, {String? username}) {
    return MessageFormatters.userTagById(userId, username: username);
  }

  String _trainingPriceLabel(int? price) {
    return MessageFormatters.trainingPriceLabel(price);
  }

  String _myBookingDateLabel(
    TrainingBooking booking,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    return MessageFormatters.bookingDateLabel(
      booking,
      dateTimeFormatter,
      dateOnlyFormatter,
    );
  }

  String _myBookingParticipantLine(TrainingBooking booking) {
    if (!booking.isManagedForOther) {
      return '';
    }
    return '👤 ${_escapeHtml(booking.participantDisplayLabel)}\n';
  }

  List<String> _adminBookingIdentityLines(TrainingBooking booking) {
    final organizerTag = _userTagById(
      booking.managerUserId,
      username: booking.userUsername,
    );
    if (!booking.isManagedForOther) {
      return <String>[
        '👤 ${_escapeHtml(organizerTag)} (${booking.managerUserId})',
      ];
    }
    return <String>[
      '👤 Организатор: ${_escapeHtml(organizerTag)} (${booking.managerUserId})',
      '👥 Участник: ${_escapeHtml(booking.participantDisplayLabel)}',
    ];
  }

  String _bookingDateLabel(
    TrainingBooking booking,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    return MessageFormatters.bookingDateLabel(
      booking,
      dateTimeFormatter,
      dateOnlyFormatter,
    );
  }

  String _trainingDateLabel(
    TrainingInfo training,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    return MessageFormatters.trainingDateLabel(
      training,
      dateTimeFormatter,
      dateOnlyFormatter,
    );
  }

  String _trainingLocationLabel(TrainingInfo training) {
    final location = training.location.trim();
    if (_isOutdoorCategory(training.category)) {
      return _escapeHtml(location);
    }
    final locationUrl = training.locationUrl?.trim();
    if (locationUrl != null && locationUrl.isNotEmpty) {
      return _locationAnchor(label: location, url: locationUrl);
    }
    return _locationAnchor(label: location, url: _mapsSearchUrl(location));
  }

  String _bookingLocationLabel(TrainingBooking booking) {
    final location = booking.location.trim();
    if (MessageFormatters.isOutdoorBooking(booking)) {
      return _escapeHtml(location);
    }
    return _locationAnchor(label: location, url: _mapsSearchUrl(location));
  }

  String _bookingTitleLine(TrainingBooking booking) {
    if (MessageFormatters.isOutdoorBooking(booking)) {
      return 'Событие: ${booking.trainingTitle}';
    }
    return 'Тренировка: ${booking.trainingTitle}';
  }

  String _outdoorPrepaymentAmountLabel(TrainingBooking booking) {
    final price = booking.trainingPrice;
    if (price == null || price <= 0) {
      return '50% от полной стоимости';
    }
    final prepayment = (price / 2).ceil();
    return MessageFormatters.trainingPriceLabel(prepayment);
  }

  String _outdoorFinalPaymentAfterLabel(TrainingBooking booking) {
    final key = booking.trainingKey.toLowerCase();
    if (key.startsWith('trails|')) {
      return 'после трейла';
    }
    return 'после похода';
  }

  String _locationAnchor({
    required String label,
    required String url,
  }) {
    final escapedUrl = _escapeHtml(url);
    final escapedLabel = _escapeHtml(label);
    return '<a href="$escapedUrl">$escapedLabel</a>';
  }

  String _mapsSearchUrl(String location) {
    final query = Uri.encodeComponent(location);
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  String _labelWithCount(String label, int count) {
    return '$label ($count)';
  }

  String _groupBookingCta() {
    final deepLink = _botDeepLink();
    if (deepLink != null) {
      return 'Записаться: $deepLink';
    }
    return 'Чтобы записаться, открой бота в личке и нажми /start.';
  }

  String _groupLowSpotsTitle(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'На тренировке почти не осталось мест!',
      ActivityCategory.hikes => 'В походе почти не осталось мест!',
      ActivityCategory.trails => 'На трейле почти не осталось мест!',
    };
  }

  String _groupNoSpotsTitle(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'Места на эту тренировку закончились',
      ActivityCategory.hikes => 'В походе не осталось мест',
      ActivityCategory.trails => 'На трейле не осталось мест',
    };
  }

  bool _isOutdoorCategory(ActivityCategory category) {
    return category == ActivityCategory.hikes || category == ActivityCategory.trails;
  }

  String? _botDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=book';
  }

  String? _botStartDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=start';
  }

  String? _botReferralLink(int userId) {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=ref_$userId';
  }

  String _categoryLabel(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'Тренировки',
      ActivityCategory.hikes => 'Походы',
      ActivityCategory.trails => 'Трейлы',
    };
  }

  String _participantsLimitLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return 'без ограничений';
    }
    return 'до $participantsLimit';
  }

  String _participantsLimitValueLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return '∞';
    }
    return '$participantsLimit';
  }

  String _money(int amount) {
    return '$amount ₽';
  }

  String? _paymentTypeLabelFromNote(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return null;
    }
    if (paymentNote.startsWith('__payment_choice_partial__')) {
      return 'Предоплата';
    }
    if (paymentNote.startsWith('__payment_choice_full__')) {
      return 'Полная оплата';
    }
    return null;
  }

  String? _cleanPaymentNote(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return null;
    }
    if (paymentNote.startsWith('__payment_choice_partial__')) {
      final text = paymentNote.substring('__payment_choice_partial__'.length).trim();
      return text.isEmpty ? null : text;
    }
    if (paymentNote.startsWith('__payment_choice_full__')) {
      final text = paymentNote.substring('__payment_choice_full__'.length).trim();
      return text.isEmpty ? null : text;
    }
    return paymentNote;
  }

  String _escapeHtml(String value) => escapeHtml(value);
}
