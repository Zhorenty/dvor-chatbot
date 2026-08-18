import 'package:dvor_chatbot/src/data/google_sheets_bookings_table.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/jobs/google_sheets_bookings_export_job.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('GoogleSheetsBookingsExportJob', () {
    test('replaces the configured sheet with current bookings', () async {
      final repository = FakeBookingRepository()
        ..allBookings = [
          fakeBooking(id: 1, status: BookingStatus.paid, title: 'AM'),
          fakeBooking(id: 2, status: BookingStatus.cancelled, title: 'PM'),
        ];
      final writer = _FakeGoogleSheetsWriter();
      final job = GoogleSheetsBookingsExportJob(
        bookingRepository: repository,
        writer: writer,
        sheetTitle: 'bot_bookings',
      );

      await job.run();

      expect(writer.replaceCalls, 1);
      expect(
        writer.sheets['bot_bookings'],
        GoogleSheetsBookingsTable.rowsFrom(repository.allBookings),
      );
    });

    test('swallows writer errors so the bot keeps running', () async {
      final repository = FakeBookingRepository()..allBookings = [fakeBooking()];
      final writer = _FakeGoogleSheetsWriter()..throwOnReplace = StateError('quota');
      final job = GoogleSheetsBookingsExportJob(
        bookingRepository: repository,
        writer: writer,
      );

      await job.run();

      expect(writer.replaceCalls, 1);
    });
  });
}

final class _FakeGoogleSheetsWriter implements GoogleSheetsWriter {
  final Map<String, List<List<Object?>>> sheets = <String, List<List<Object?>>>{};
  int replaceCalls = 0;
  Object? throwOnReplace;

  @override
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {
    replaceCalls += 1;
    final error = throwOnReplace;
    if (error != null) {
      throw error;
    }
    sheets[sheetTitle] = [
      for (final row in rows) List<Object?>.from(row),
    ];
  }

  @override
  Future<void> close() async {}
}
