/// Converts a timestamp into the club business timezone used by scheduled jobs.
DateTime inBusinessTimezone(
  DateTime value, {
  required int timezoneOffsetHours,
}) {
  return value.toUtc().add(Duration(hours: timezoneOffsetHours));
}
