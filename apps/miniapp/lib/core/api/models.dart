import 'package:flutter/widgets.dart';

enum EventCategory {
  trainings,
  hikes,
  trails;

  static EventCategory parse(Object? raw) => switch (raw) {
    'hikes' => EventCategory.hikes,
    'trails' => EventCategory.trails,
    _ => EventCategory.trainings,
  };

  String get label => switch (this) {
    EventCategory.trainings => 'Тренировки',
    EventCategory.hikes => 'Походы',
    EventCategory.trails => 'Трейлы и кэмпы',
  };

  String get shortLabel => switch (this) {
    EventCategory.trainings => 'Тренировка',
    EventCategory.hikes => 'Поход',
    EventCategory.trails => 'Трейл',
  };

  bool get isOutdoor => this != EventCategory.trainings;
}

DateTime _date(Object? raw) => DateTime.parse(raw! as String).toUtc();

DateTime? _dateOrNull(Object? raw) => raw is String ? DateTime.parse(raw).toUtc() : null;

String? _str(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

@immutable
class ClubEvent {
  const ClubEvent({
    required this.key,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.location,
    this.endsAt,
    this.locationUrl,
    this.price,
    this.prepayPercent,
    this.limit,
    this.taken,
    this.coach,
    this.notes,
    this.description,
    this.equipment,
    this.itinerary,
  });

  factory ClubEvent.fromJson(Map<String, Object?> json) => ClubEvent(
    key: json['key']! as String,
    category: EventCategory.parse(json['category']),
    title: (json['title'] as String?)?.trim() ?? '',
    startsAt: _date(json['startsAt']),
    endsAt: _dateOrNull(json['endsAt']),
    location: (json['location'] as String?)?.trim() ?? '',
    locationUrl: _str(json['locationUrl']),
    price: _int(json['price']),
    prepayPercent: _int(json['prepayPercent']),
    limit: _int(json['limit']),
    taken: _int(json['taken']),
    coach: _str(json['coach']),
    notes: _str(json['notes']),
    description: _str(json['description']),
    equipment: _str(json['equipment']),
    itinerary: _str(json['itinerary']),
  );

  final String key;
  final EventCategory category;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String location;
  final String? locationUrl;
  final int? price;
  final int? prepayPercent;
  final int? limit;
  final int? taken;
  final String? coach;
  final String? notes;
  final String? description;
  final String? equipment;
  final String? itinerary;

  bool get isFree => price != null && price! <= 0;

  int? get seatsLeft {
    final cap = limit;
    if (cap == null || cap <= 0) {
      return null;
    }
    return (cap - (taken ?? 0)).clamp(0, cap);
  }

  bool get isFull => seatsLeft == 0;

  bool get isMultiDay {
    final end = endsAt;
    if (end == null) {
      return false;
    }
    final a = startsAt.add(const Duration(hours: 3));
    final b = end.add(const Duration(hours: 3));
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}

enum BookingStatus {
  pendingPayment,
  paymentSubmitted,
  partialPaid,
  paid,
  freeTraining,
  paymentRejected,
  cancelled;

  static BookingStatus parse(Object? raw) => switch (raw) {
    'payment_submitted' => BookingStatus.paymentSubmitted,
    'partial_paid' => BookingStatus.partialPaid,
    'paid' => BookingStatus.paid,
    'free_training' => BookingStatus.freeTraining,
    'payment_rejected' => BookingStatus.paymentRejected,
    'cancelled' => BookingStatus.cancelled,
    _ => BookingStatus.pendingPayment,
  };

  String get label => switch (this) {
    BookingStatus.pendingPayment => 'Ждёт оплаты',
    BookingStatus.paymentSubmitted => 'Чек на проверке',
    BookingStatus.partialPaid => 'Предоплата внесена',
    BookingStatus.paid => 'Оплачено',
    BookingStatus.freeTraining => 'Бесплатно',
    BookingStatus.paymentRejected => 'Оплата отклонена',
    BookingStatus.cancelled => 'Отменено',
  };

  bool get needsPayment =>
      this == BookingStatus.pendingPayment || this == BookingStatus.paymentRejected;

  bool get isActive => this != BookingStatus.cancelled && this != BookingStatus.paymentRejected;
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.key,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.location,
    required this.status,
    this.locationUrl,
    this.price,
    this.prepayPercent,
    this.participant,
    this.canCancel = false,
    this.boxingCard = false,
    this.attended = false,
  });

  factory Booking.fromJson(Map<String, Object?> json) => Booking(
    id: _int(json['id'])!,
    key: json['key']! as String,
    category: EventCategory.parse(json['category']),
    title: (json['title'] as String?)?.trim() ?? '',
    startsAt: _date(json['startsAt']),
    location: (json['location'] as String?)?.trim() ?? '',
    locationUrl: _str(json['locationUrl']),
    status: BookingStatus.parse(json['status']),
    price: _int(json['price']),
    prepayPercent: _int(json['prepayPercent']),
    participant: _str(json['participant']),
    canCancel: json['canCancel'] == true,
    boxingCard: json['boxingCard'] == true,
    attended: json['attendance'] == 'attended',
  );

  final int id;
  final String key;
  final EventCategory category;
  final String title;
  final DateTime startsAt;
  final String location;
  final String? locationUrl;
  final BookingStatus status;
  final int? price;
  final int? prepayPercent;
  final String? participant;
  final bool canCancel;
  final bool boxingCard;
  final bool attended;
}

@immutable
class Me {
  const Me({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
    this.isAdmin = false,
    this.peaks = 0,
    this.visits = 0,
    this.invited = 0,
    this.bookings = 0,
    this.botUsername,
    this.referralLink,
  });

  factory Me.fromJson(Map<String, Object?> json) {
    final user = (json['user'] as Map<String, Object?>?) ?? const {};
    final profile = (json['profile'] as Map<String, Object?>?) ?? const {};
    return Me(
      id: _int(user['id']) ?? 0,
      firstName: _str(user['first_name']) ?? '',
      lastName: _str(user['last_name']),
      username: _str(user['username']),
      photoUrl: _str(user['photo_url']),
      isAdmin: json['isAdmin'] == true,
      peaks: _int(profile['peaks']) ?? 0,
      visits: _int(profile['visits']) ?? 0,
      invited: _int(profile['invited']) ?? 0,
      bookings: _int(profile['bookings']) ?? 0,
      botUsername: _str(json['botUsername']),
      referralLink: _str(json['referralLink']),
    );
  }

  final int id;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;
  final bool isAdmin;
  final int peaks;
  final int visits;
  final int invited;
  final int bookings;
  final String? botUsername;
  final String? referralLink;

  String get initials {
    final first = firstName.isEmpty ? '' : firstName.characters.first;
    final last = (lastName == null || lastName!.isEmpty) ? '' : lastName!.characters.first;
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'D' : value;
  }
}

enum ActionOutcome { created, exists, cancelled }

@immutable
class ActionResult {
  const ActionResult({required this.outcome, this.booking, this.refundPeaks});

  factory ActionResult.fromJson(Map<String, Object?> json) => ActionResult(
    outcome: switch (json['outcome']) {
      'exists' => ActionOutcome.exists,
      'cancelled' => ActionOutcome.cancelled,
      _ => ActionOutcome.created,
    },
    booking: json['booking'] is Map<String, Object?>
        ? Booking.fromJson(json['booking']! as Map<String, Object?>)
        : null,
    refundPeaks: _int(json['refundPeaks']),
  );

  final ActionOutcome outcome;
  final Booking? booking;
  final int? refundPeaks;
}

/// Server error with a user-facing message.
class ApiException implements Exception {
  const ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}
