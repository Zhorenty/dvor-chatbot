import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_bookings_table.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:l/l.dart';

final class GoogleSheetsBookingsExportJob {
  const GoogleSheetsBookingsExportJob({
    required BookingRepository bookingRepository,
    required GoogleSheetsWriter writer,
    this.sheetTitle = 'bot_bookings',
  })  : _bookingRepository = bookingRepository,
        _writer = writer;

  final BookingRepository _bookingRepository;
  final GoogleSheetsWriter _writer;
  final String sheetTitle;

  Future<void> run() async {
    try {
      final bookings = await _bookingRepository.listAllBookings();
      await _writer.replaceSheet(
        sheetTitle: sheetTitle,
        rows: GoogleSheetsBookingsTable.rowsFrom(bookings),
      );
      l.i(
        'Google Sheets bookings export completed. '
        'sheet=$sheetTitle rows=${bookings.length}',
      );
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets bookings export failed: $error', stackTrace);
    }
  }
}
