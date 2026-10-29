import 'package:dvor_miniapp/core/api/models.dart';
import 'package:flutter/foundation.dart';

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

String? _str(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

Map<String, Object?> _map(Object? raw) => raw is Map<String, Object?> ? raw : const {};

List<Map<String, Object?>> _list(Object? raw) =>
    raw is List ? raw.whereType<Map<String, Object?>>().toList() : const [];

/// What can be done to pay for one booking (`payment.options`).
@immutable
class PaymentOptions {
  const PaymentOptions({
    required this.payable,
    required this.amount,
    required this.participants,
    required this.sbpLink,
    this.prepayPercent,
    this.prepayAmount,
    this.outdoorChoice = false,
    this.starterBonus = false,
    this.peaksBalance = 0,
    this.peaksAvailable = false,
    this.peaksSpend = 0,
    this.peaksRemainder,
    this.peaksCoverFully = false,
    this.promo = false,
    this.promoCode,
    this.booking,
  });

  factory PaymentOptions.fromJson(Map<String, Object?> json) {
    final peaks = _map(json['peaks']);
    return PaymentOptions(
      payable: json['payable'] == true,
      amount: _int(json['amount']) ?? 0,
      participants: _int(json['participants']) ?? 1,
      sbpLink: _str(json['sbpLink']) ?? '',
      prepayPercent: _int(json['prepayPercent']),
      prepayAmount: _int(json['prepayAmount']),
      outdoorChoice: json['outdoorChoice'] == true,
      starterBonus: json['starterBonus'] == true,
      peaksBalance: _int(peaks['balance']) ?? 0,
      peaksAvailable: peaks['available'] == true,
      peaksSpend: _int(peaks['spend']) ?? 0,
      peaksRemainder: _int(peaks['remainderRub']),
      peaksCoverFully: peaks['coversFully'] == true,
      promo: json['promo'] == true,
      promoCode: _str(json['promoCode']),
      booking: json['booking'] is Map<String, Object?>
          ? Booking.fromJson(json['booking']! as Map<String, Object?>)
          : null,
    );
  }

  final bool payable;
  final int amount;
  final int participants;
  final String sbpLink;
  final int? prepayPercent;
  final int? prepayAmount;
  final bool outdoorChoice;
  final bool starterBonus;
  final int peaksBalance;
  final bool peaksAvailable;
  final int peaksSpend;
  final int? peaksRemainder;
  final bool peaksCoverFully;
  final bool promo;
  final String? promoCode;
  final Booking? booking;
}

@immutable
class CardPlan {
  const CardPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.trainings,
    required this.individual,
    required this.peaksSpend,
    required this.peaksRemainder,
    required this.peaksCoverFully,
  });

  factory CardPlan.fromJson(Map<String, Object?> json) {
    final quote = _map(json['peaksQuote']);
    return CardPlan(
      id: _str(json['id']) ?? '',
      name: _str(json['name']) ?? '',
      price: _int(json['price']) ?? 0,
      trainings: _int(json['trainings']) ?? 0,
      individual: _int(json['individual']) ?? 0,
      peaksSpend: _int(quote['spend']) ?? 0,
      peaksRemainder: _int(quote['remainderRub']) ?? 0,
      peaksCoverFully: quote['coversFully'] == true,
    );
  }

  final String id;
  final String name;
  final int price;
  final int trainings;
  final int individual;
  final int peaksSpend;
  final int peaksRemainder;
  final bool peaksCoverFully;
}

/// BOXING CARD state and plans (`card.overview`).
@immutable
class CardOverview {
  const CardOverview({
    required this.active,
    required this.plans,
    required this.sbpLink,
    this.planId,
    this.activeUntil,
    this.remaining,
    this.quota,
    this.individualUsed,
    this.pendingPlan,
    this.pendingSince,
    this.peaksBalance = 0,
  });

  factory CardOverview.fromJson(Map<String, Object?> json) {
    final pending = json['pending'] is Map<String, Object?> ? _map(json['pending']) : null;
    return CardOverview(
      active: json['active'] == true,
      plans: _list(json['plans']).map(CardPlan.fromJson).toList(),
      sbpLink: _str(json['sbpLink']) ?? '',
      planId: _str(json['plan']),
      activeUntil: _date(json['activeUntil']),
      remaining: _int(json['remaining']),
      quota: _int(json['quota']),
      individualUsed: json['individualUsed'] as bool?,
      pendingPlan: pending == null ? null : _str(pending['plan']),
      pendingSince: pending == null ? null : _date(pending['createdAt']),
      peaksBalance: _int(json['peaksBalance']) ?? 0,
    );
  }

  final bool active;
  final List<CardPlan> plans;
  final String sbpLink;
  final String? planId;
  final DateTime? activeUntil;
  final int? remaining;
  final int? quota;
  final bool? individualUsed;
  final String? pendingPlan;
  final DateTime? pendingSince;
  final int peaksBalance;

  bool get pending => pendingPlan != null;

  CardPlan? get plan => plans.where((p) => p.id == planId).firstOrNull;
}

@immutable
class TeamPerson {
  const TeamPerson({
    required this.name,
    required this.role,
    required this.isTrainer,
    this.description,
    this.link,
  });

  factory TeamPerson.fromJson(Map<String, Object?> json) => TeamPerson(
    name: _str(json['name']) ?? '',
    role: _str(json['role']) ?? '',
    isTrainer: json['kind'] == 'trainer',
    description: _str(json['description']),
    link: _str(json['link']),
  );

  final String name;
  final String role;
  final bool isTrainer;
  final String? description;
  final String? link;
}

/// Pending BOXING CARD request for admins.
@immutable
class CardRequest {
  const CardRequest({
    required this.id,
    required this.createdAt,
    this.username,
    this.planName,
    this.price,
    this.note,
    this.peaksSpent = 0,
    this.hasProof = false,
  });

  factory CardRequest.fromJson(Map<String, Object?> json) => CardRequest(
    id: _int(json['id']) ?? 0,
    createdAt: _date(json['createdAt']) ?? DateTime.utc(1970),
    username: _str(json['username']),
    planName: _str(json['planName']),
    price: _int(json['price']),
    note: _str(json['note']),
    peaksSpent: _int(json['peaksSpent']) ?? 0,
    hasProof: json['hasProof'] == true,
  );

  final int id;
  final DateTime createdAt;
  final String? username;
  final String? planName;
  final int? price;
  final String? note;
  final int peaksSpent;
  final bool hasProof;
}

/// Row of the schedule sheet for admin editing.
@immutable
class CatalogItem {
  const CatalogItem({
    required this.row,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.fields,
  });

  factory CatalogItem.fromJson(Map<String, Object?> json) => CatalogItem(
    row: _int(json['row']) ?? 0,
    category: EventCategory.parse(json['category']),
    title: _str(json['title']) ?? '',
    startsAt: _date(json['startsAt']) ?? DateTime.utc(1970),
    fields: {for (final e in _map(json['fields']).entries) e.key: e.value?.toString() ?? ''},
  );

  final int row;
  final EventCategory category;
  final String title;
  final DateTime startsAt;
  final Map<String, String> fields;
}

/// Booking as admins see it.
@immutable
class AdminBooking {
  const AdminBooking({
    required this.booking,
    required this.participant,
    this.manager,
    this.paymentNote,
    this.promoCode,
  });

  factory AdminBooking.fromJson(Map<String, Object?> json) => AdminBooking(
    booking: Booking.fromJson(json),
    participant: _str(json['participant']) ?? '',
    manager: _str(json['manager']),
    paymentNote: _str(json['paymentNote']),
    promoCode: _str(json['promoCode']),
  );

  final Booking booking;
  final String participant;
  final String? manager;
  final String? paymentNote;
  final String? promoCode;
}

List<T> parseList<T>(Object? raw, T Function(Map<String, Object?>) parse) =>
    _list(raw).map(parse).toList();
