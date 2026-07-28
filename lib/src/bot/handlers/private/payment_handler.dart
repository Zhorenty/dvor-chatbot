/// Payment-flow UX helpers for private chat orchestration.
final class PaymentHandler {
  const PaymentHandler();

  String chooseBookingFirstText(String buttonBookTrainingLabel) {
    return 'Сначала выбери мероприятие через «$buttonBookTrainingLabel», '
        'потом вернись к подтверждению оплаты.';
  }

  bool hasPartialPaymentChoice(String? paymentNote) {
    final note = paymentNote ?? '';
    return note.contains('__payment_choice_partial__');
  }
}
