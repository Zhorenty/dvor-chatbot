import 'package:dvor_chatbot/src/data/google_sheets_bookings_table.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('GoogleSheetsBookingsTable', () {
    test('writes a header and one data row', () {
      final booking = fakeBooking(
        id: 7,
        userId: 42,
        userUsername: 'ivan',
        trainingKey: 'hikes|2026-08-01T10:00:00.000Z|Trail|Forest',
        title: 'Хайк',
        startsAt: DateTime(2026, 8, 1, 10),
        location: 'Forest',
        status: BookingStatus.paid,
        trainingPrice: 1500,
        promoCode: 'DVOR10',
        promoDiscountPercent: 10,
        createdAt: DateTime(2026, 7, 30, 12),
        updatedAt: DateTime(2026, 7, 31, 9),
      );

      final rows = GoogleSheetsBookingsTable.rowsFrom([booking]);
      expect(rows, hasLength(2));
      expect(rows.first, GoogleSheetsBookingsTable.header);
      expect(rows.last[0], 7);
      expect(rows.last[1], 42);
      expect(rows.last[2], 'ivan');
      expect(rows.last[5], 'paid');
      expect(rows.last[6], 'hikes');
      expect(rows.last[7], 'Хайк');
      expect(rows.last[8], '2026-08-01 10:00');
      expect(rows.last[10], 1500);
      expect(rows.last[11], 'DVOR10');
    });

    test('falls back to trainings when trainingKey has no category prefix', () {
      expect(GoogleSheetsBookingsTable.categoryOf(fakeBooking()), 'trainings');
    });
  });
}
