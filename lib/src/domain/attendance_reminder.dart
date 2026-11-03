/// A past training whose attendance roster is still open.
final class AttendanceReminderSession {
  const AttendanceReminderSession({
    required this.trainingTitle,
    required this.startsAt,
    required this.unmarked,
  });

  final String trainingTitle;
  final DateTime startsAt;
  final int unmarked;
}
