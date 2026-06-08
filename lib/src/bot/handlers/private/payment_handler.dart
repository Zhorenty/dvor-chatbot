final class PaymentHandler {
  const PaymentHandler();

  String chooseBookingFirstText(String buttonBookTrainingLabel) {
    return 'Сначала выбери мероприятие через «$buttonBookTrainingLabel», '
        'потом вернись к подтверждению оплаты.';
  }
}
