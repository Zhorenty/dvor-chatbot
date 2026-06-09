enum BookingStatus {
  pendingPayment,
  paymentSubmitted,
  partialPaid,
  paid,
  freeTraining,
  paymentRejected,
  cancelled;

  String get dbValue => switch (this) {
        BookingStatus.pendingPayment => 'pending_payment',
        BookingStatus.paymentSubmitted => 'payment_submitted',
        BookingStatus.partialPaid => 'partial_paid',
        BookingStatus.paid => 'paid',
        BookingStatus.freeTraining => 'free_training',
        BookingStatus.paymentRejected => 'payment_rejected',
        BookingStatus.cancelled => 'cancelled',
      };

  static BookingStatus fromDbValue(String value) {
    return switch (value) {
      'pending_payment' => BookingStatus.pendingPayment,
      'payment_submitted' => BookingStatus.paymentSubmitted,
      'partial_paid' => BookingStatus.partialPaid,
      'paid' => BookingStatus.paid,
      'free_training' => BookingStatus.freeTraining,
      'payment_rejected' => BookingStatus.paymentRejected,
      'cancelled' => BookingStatus.cancelled,
      _ => BookingStatus.pendingPayment,
    };
  }
}
