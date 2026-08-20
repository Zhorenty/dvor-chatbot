import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:intl/intl.dart';

/// Shared cell parsing for schedule CSV and catalog write paths.
abstract final class GoogleSheetsValueParser {
  static String normalizeHeader(String value) => GoogleSheetsInputUi.normalizeHeader(value);

  static String cellString(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool) {
      return value ? 'TRUE' : 'FALSE';
    }
    return value.toString().trim();
  }

  static String cell(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return cellString(row[index]);
  }

  static String? optionalCell(List<Object?> row, int index) {
    final value = cell(row, index);
    return value.isEmpty ? null : value;
  }

  static int firstHeaderIndex(List<String> headers, List<String> aliases) {
    for (final alias in aliases) {
      final index = headers.indexOf(alias);
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  static DateTime? parseDateTime(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(normalized);
    if (isoDate != null) {
      return isoDate.isUtc ? isoDate.toLocal() : isoDate;
    }

    final localFormats = <DateFormat>[
      DateFormat('dd.MM.yyyy HH:mm:ss'),
      DateFormat('dd.MM.yyyy H:mm:ss'),
      DateFormat('dd.MM.yyyy HH:mm'),
      DateFormat('dd.MM.yyyy H:mm'),
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd H:mm:ss'),
      DateFormat('yyyy-MM-dd HH:mm'),
      DateFormat('yyyy-MM-dd H:mm'),
    ];
    for (final format in localFormats) {
      try {
        return format.parseStrict(normalized);
      } on FormatException {
        // Try next format.
      }
    }
    return null;
  }

  static DateTime? parseDateAndTime(String dateRaw, String timeRaw) {
    final dateNormalized = dateRaw.trim();
    final timeNormalized = timeRaw.trim();
    if (dateNormalized.isEmpty || timeNormalized.isEmpty) {
      return null;
    }

    final combined = parseDateTime('$dateNormalized $timeNormalized');
    if (combined != null) {
      return combined;
    }

    final date = parseDate(dateNormalized);
    final time = parseTime(timeNormalized);
    if (date == null || time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second);
  }

  static DateTime? parseDate(String raw) {
    final dateOnlyFormats = <DateFormat>[
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd.MM.yyyy'),
      DateFormat('d.M.yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('M/d/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
    ];

    for (final format in dateOnlyFormats) {
      try {
        return format.parseStrict(raw.trim());
      } on FormatException {
        // Try next format.
      }
    }

    return null;
  }

  static DateTime? parseTime(String raw) {
    final timeFormats = <DateFormat>[
      DateFormat('HH:mm:ss'),
      DateFormat('H:mm:ss'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
      DateFormat('hh:mm a'),
      DateFormat('h:mm a'),
    ];

    for (final format in timeFormats) {
      try {
        return format.parseStrict(raw.trim());
      } on FormatException {
        // Try next format.
      }
    }

    return null;
  }

  static DateTime? parseRangeDateTime(String raw, {required bool isEndOfDay}) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final parsedDateTime = parseDateTime(normalized);
    if (parsedDateTime != null) {
      final likelyDateOnly = !RegExp(r'[:T]').hasMatch(normalized);
      if (!likelyDateOnly) {
        return parsedDateTime;
      }
      return isEndOfDay
          ? DateTime(
              parsedDateTime.year,
              parsedDateTime.month,
              parsedDateTime.day,
              23,
              59,
              59,
            )
          : DateTime(parsedDateTime.year, parsedDateTime.month, parsedDateTime.day);
    }

    final dateOnly = parseDate(normalized);
    if (dateOnly == null) {
      return null;
    }

    return isEndOfDay
        ? DateTime(dateOnly.year, dateOnly.month, dateOnly.day, 23, 59, 59)
        : DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
  }

  static int? parsePrice(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return null;
    }
    return int.tryParse(digitsOnly);
  }

  static int? parseParticipantsLimit(String? raw) {
    final parsed = parsePrice(raw);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static int parsePrepayPercent(String? raw, {int defaultPercent = 50}) {
    final parsed = parsePrepayPercentOrNull(raw);
    return parsed ?? defaultPercent;
  }

  static int? parsePrepayPercentOrNull(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(digitsOnly);
    if (parsed == null || parsed < 1 || parsed > 100) {
      return null;
    }
    return parsed;
  }

  static bool parseBoolFlag(String? raw, {bool defaultValue = false}) {
    if (raw == null) {
      return defaultValue;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return defaultValue;
    }
    if (const <String>{
      '1',
      'true',
      'yes',
      'y',
      'on',
      'да',
      'д',
    }.contains(normalized)) {
      return true;
    }
    if (const <String>{
      '0',
      'false',
      'no',
      'n',
      'off',
      'нет',
      'н',
    }.contains(normalized)) {
      return false;
    }
    return defaultValue;
  }

  static String formatDate(DateTime value) {
    return DateFormat('dd.MM.yyyy').format(value);
  }

  static String formatTime(DateTime value) {
    return DateFormat('H:mm').format(value);
  }
}
