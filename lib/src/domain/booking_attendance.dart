enum BookingAttendance {
  attended,
  absent;

  String get dbValue => switch (this) {
        BookingAttendance.attended => 'attended',
        BookingAttendance.absent => 'absent',
      };

  static BookingAttendance? fromDbValue(String? value) {
    return switch (value) {
      'attended' => BookingAttendance.attended,
      'absent' => BookingAttendance.absent,
      _ => null,
    };
  }
}
