import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:sqlite3/sqlite3.dart';

final class PendingPaymentExpiryPolicy {
  const PendingPaymentExpiryPolicy();

  void expire({
    required Database database,
    required String cutoffIsoUtc,
    required String nowIsoUtc,
  }) {
    // Cancel overdue seats and any sibling seats in the same payment group so
    // party bookings never leave orphan pending places after TTL.
    database.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE status = ?
        AND (
          created_at < ?
          OR (
            payment_group_id IS NOT NULL
            AND TRIM(payment_group_id) != ''
            AND payment_group_id IN (
              SELECT payment_group_id
              FROM bookings
              WHERE status = ?
                AND created_at < ?
                AND payment_group_id IS NOT NULL
                AND TRIM(payment_group_id) != ''
            )
          )
        );
      ''',
      <Object?>[
        BookingStatus.cancelled.dbValue,
        nowIsoUtc,
        BookingStatus.pendingPayment.dbValue,
        cutoffIsoUtc,
        BookingStatus.pendingPayment.dbValue,
        cutoffIsoUtc,
      ],
    );
  }
}
