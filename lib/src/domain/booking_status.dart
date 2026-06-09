enum BookingStatus {
  pendingPayment,
  paymentSubmitted,
  paid,
  freeTraining,
  paymentRejected,
  cancelled;

  String get dbValue => switch (this) {
        BookingStatus.pendingPayment => 'pending_payment',
        BookingStatus.paymentSubmitted => 'payment_submitted',
        BookingStatus.paid => 'paid',
        BookingStatus.freeTraining => 'free_training',
        BookingStatus.paymentRejected => 'payment_rejected',
        BookingStatus.cancelled => 'cancelled',
      };

  static BookingStatus fromDbValue(String value) {
    return switch (value) {
      'pending_payment' => BookingStatus.pendingPayment,
      'payment_submitted' => BookingStatus.paymentSubmitted,
      'paid' => BookingStatus.paid,
      'free_training' => BookingStatus.freeTraining,
      'payment_rejected' => BookingStatus.paymentRejected,
      'cancelled' => BookingStatus.cancelled,
      _ => BookingStatus.pendingPayment,
    };
  }
}
