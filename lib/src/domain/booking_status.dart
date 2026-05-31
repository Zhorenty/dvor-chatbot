enum BookingStatus {
  pendingPayment,
  paymentSubmitted,
  paid,
  paymentRejected,
  cancelled;

  String get dbValue => switch (this) {
        BookingStatus.pendingPayment => 'pending_payment',
        BookingStatus.paymentSubmitted => 'payment_submitted',
        BookingStatus.paid => 'paid',
        BookingStatus.paymentRejected => 'payment_rejected',
        BookingStatus.cancelled => 'cancelled',
      };

  static BookingStatus fromDbValue(String value) {
    return switch (value) {
      'pending_payment' => BookingStatus.pendingPayment,
      'payment_submitted' => BookingStatus.paymentSubmitted,
      'paid' => BookingStatus.paid,
      'payment_rejected' => BookingStatus.paymentRejected,
      'cancelled' => BookingStatus.cancelled,
      _ => BookingStatus.pendingPayment,
    };
  }
}
