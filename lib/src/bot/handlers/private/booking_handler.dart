/// Booking UX helpers extracted from private orchestration.
final class BookingHandler {
  const BookingHandler();

  String unknownSelectionText() =>
      'Не понял выбор. Отправь номер из списка или нажми кнопку с нужным мероприятием 👇';

  bool isCapacityConfirmedStatus(String statusDbValue) {
    return statusDbValue == 'paid' ||
        statusDbValue == 'payment_submitted' ||
        statusDbValue == 'partial_paid' ||
        statusDbValue == 'free_training';
  }
}
