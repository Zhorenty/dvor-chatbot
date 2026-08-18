import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:intl/intl.dart';

/// Flat table dumped to the `bot_bookings` sheet. SQLite stays the source of truth.
abstract final class GoogleSheetsBookingsTable {
  static const List<Object?> header = <Object?>[
    'id',
    'user_id',
    'username',
    'participant',
    'participant_type',
    'status',
    'category',
    'title',
    'starts_at',
    'location',
    'price',
    'promo_code',
    'promo_discount_percent',
    'created_at',
    'updated_at',
    'payment_group_id',
  ];

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  static List<List<Object?>> rowsFrom(List<TrainingBooking> bookings) {
    return <List<Object?>>[
      header,
      ...bookings.map(toRow),
    ];
  }

  static List<Object?> toRow(TrainingBooking booking) {
    return <Object?>[
      booking.id,
      booking.userId,
      booking.userUsername ?? '',
      booking.participantDisplayLabel,
      booking.participantType.dbValue,
      booking.status.dbValue,
      categoryOf(booking),
      booking.trainingTitle,
      _dateFormat.format(booking.startsAt),
      booking.location,
      booking.trainingPrice ?? '',
      booking.promoCode ?? '',
      booking.promoDiscountPercent ?? '',
      _dateFormat.format(booking.createdAt),
      _dateFormat.format(booking.updatedAt),
      booking.paymentGroupId ?? '',
    ];
  }

  static String categoryOf(TrainingBooking booking) {
    final key = booking.trainingKey;
    final index = key.indexOf('|');
    if (index <= 0) {
      return ActivityCategory.trainings.name;
    }
    return key.substring(0, index);
  }
}
