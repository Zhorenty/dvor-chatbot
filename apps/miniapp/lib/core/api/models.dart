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
    EventCategory.trails => 'Кэмпы',
  };

  String get shortLabel => switch (this) {
    EventCategory.trainings => 'Тренировка',
    EventCategory.hikes => 'Поход',
    EventCategory.trails => 'Кэмп',
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

  /// Seats are shown only when they run out: under 30% free, the same rule
  /// the bot uses for the "места заканчиваются" group post. Null otherwise.
  int? get lowSeats {
    final left = seatsLeft;
    final cap = limit;
    if (left == null || cap == null || cap <= 0) {
      return null;
    }
    return left / cap < lowSeatsShare ? left : null;
  }

  static const double lowSeatsShare = 0.3;

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
    this.peaksExpireAt,
    this.peaksHistory = const [],
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
      peaksExpireAt: _dateOrNull(profile['peaksExpireAt']),
      peaksHistory: ((profile['peaksHistory'] as List<Object?>?) ?? const [])
          .whereType<Map<String, Object?>>()
          .map(PeaksChange.fromJson)
          .toList(growable: false),
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

  /// When the ⛰️ balance burns without new activity (bot rule: 45 days).
  final DateTime? peaksExpireAt;
  final List<PeaksChange> peaksHistory;

  String get initials {
    final first = firstName.isEmpty ? '' : firstName.characters.first;
    final last = (lastName == null || lastName!.isEmpty) ? '' : lastName!.characters.first;
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'D' : value;
  }
}

/// One loyalty ledger row; [reason] is the bot's db value.
@immutable
class PeaksChange {
  const PeaksChange({required this.amount, required this.reason, required this.createdAt});

  factory PeaksChange.fromJson(Map<String, Object?> json) => PeaksChange(
    amount: _int(json['amount']) ?? 0,
    reason: (json['reason'] as String?) ?? '',
    createdAt: _dateOrNull(json['createdAt']) ?? DateTime.utc(1970),
  );

  final int amount;
  final String reason;
  final DateTime createdAt;

  String get label => switch (reason) {
    'start' => 'Стартовые',
    'training' => 'Тренировка',
    'feedback' => 'Отзыв',
    'hike' => 'Поход',
    'trail' => 'Кэмп',
    'referral' => 'Друг пришёл',
    'boxing_card' => 'BOXING CARD',
    'expire' => 'Сгорели',
    'spend' => 'Списание',
    'refund' => 'Возврат за отмену',
    'admin_grant' => 'Начисление от клуба',
    'admin_debit' => 'Списание клубом',
    'migration' => 'Перенос баланса',
    _ => 'Вершинки',
  };
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

enum PaymentDecision {
  approve('approve'),
  approvePartial('approve_partial'),
  reject('reject');

  const PaymentDecision(this.wire);

  final String wire;
}

/// Submitted payment awaiting review, one per payment group.
@immutable
class AdminPayment {
  const AdminPayment({
    required this.id,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.location,
    required this.organizer,
    this.organizerId,
    this.price,
    this.prepayPercent,
    this.total = 0,
    this.partial = false,
    this.comment,
    this.promoCode,
    this.participants = const [],
    this.hasProof = false,
  });

  factory AdminPayment.fromJson(Map<String, Object?> json) {
    final organizer = (json['organizer'] as Map<String, Object?>?) ?? const {};
    return AdminPayment(
      id: _int(json['id'])!,
      category: EventCategory.parse(json['category']),
      title: (json['title'] as String?)?.trim() ?? '',
      startsAt: _date(json['startsAt']),
      location: (json['location'] as String?)?.trim() ?? '',
      organizer: _str(organizer['name']) ?? '',
      organizerId: _int(organizer['userId']),
      price: _int(json['price']),
      prepayPercent: _int(json['prepayPercent']),
      total: _int(json['total']) ?? 0,
      partial: json['paymentType'] == 'partial',
      comment: _str(json['comment']),
      promoCode: _str(json['promoCode']),
      participants: ((json['participants'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toList(),
      hasProof: json['hasProof'] == true,
    );
  }

  final int id;
  final EventCategory category;
  final String title;
  final DateTime startsAt;
  final String location;
  final String organizer;
  final int? organizerId;
  final int? price;
  final int? prepayPercent;
  final int total;
  final bool partial;
  final String? comment;
  final String? promoCode;
  final List<String> participants;
  final bool hasProof;
}

/// Event with its roster summary for the admin lists.
@immutable
class AdminSession {
  const AdminSession({
    required this.key,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.location,
    this.limit,
    this.participants = 0,
    this.attendanceOpen = false,
    this.unmarked = 0,
  });

  factory AdminSession.fromJson(Map<String, Object?> json) => AdminSession(
    key: json['key']! as String,
    category: EventCategory.parse(json['category']),
    title: (json['title'] as String?)?.trim() ?? '',
    startsAt: _date(json['startsAt']),
    location: (json['location'] as String?)?.trim() ?? '',
    limit: _int(json['limit']),
    participants: _int(json['participants']) ?? 0,
    attendanceOpen: json['attendanceOpen'] == true,
    unmarked: _int(json['unmarked']) ?? 0,
  );

  final String key;
  final EventCategory category;
  final String title;
  final DateTime startsAt;
  final String location;
  final int? limit;
  final int participants;
  final bool attendanceOpen;
  final int unmarked;
}

enum Attendance {
  attended('attended'),
  absent('absent');

  const Attendance(this.wire);

  final String wire;

  static Attendance? parse(Object? raw) => switch (raw) {
    'attended' => Attendance.attended,
    'absent' => Attendance.absent,
    _ => null,
  };
}

@immutable
class AdminParticipant {
  const AdminParticipant({
    required this.bookingId,
    required this.name,
    required this.status,
    this.guest = false,
    this.managedBy,
    this.boxingCard = false,
    this.attendance,
    this.canMark = false,
  });

  factory AdminParticipant.fromJson(Map<String, Object?> json) => AdminParticipant(
    bookingId: _int(json['bookingId'])!,
    name: _str(json['name']) ?? 'Участник',
    status: BookingStatus.parse(json['status']),
    guest: json['guest'] == true,
    managedBy: _str(json['managedBy']),
    boxingCard: json['boxingCard'] == true,
    attendance: Attendance.parse(json['attendance']),
    canMark: json['canMark'] == true,
  );

  final int bookingId;
  final String name;
  final BookingStatus status;
  final bool guest;
  final String? managedBy;
  final bool boxingCard;
  final Attendance? attendance;
  final bool canMark;
}

@immutable
class Roster {
  const Roster({required this.session, required this.participants});

  final AdminSession session;
  final List<AdminParticipant> participants;
}

/// Server error with a user-facing message.
class ApiException implements Exception {
  const ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}
