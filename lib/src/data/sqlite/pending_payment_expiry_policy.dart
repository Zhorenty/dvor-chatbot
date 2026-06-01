import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:sqlite3/sqlite3.dart';

final class PendingPaymentExpiryPolicy {
  const PendingPaymentExpiryPolicy();

  void expire({
    required Database database,
    required String cutoffIsoUtc,
    required String nowIsoUtc,
  }) {
    database.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE status = ? AND created_at < ?;
      ''',
      <Object?>[
        BookingStatus.cancelled.dbValue,
        nowIsoUtc,
        BookingStatus.pendingPayment.dbValue,
        cutoffIsoUtc,
      ],
    );
  }
}
