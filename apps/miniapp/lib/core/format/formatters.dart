import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Club time is Moscow (UTC+3, no DST), same as the bot.
abstract final class ClubTime {
  static const Duration offset = Duration(hours: 3);

  static DateTime local(DateTime utc) => utc.toUtc().add(offset);

  static DateTime today(DateTime nowUtc) {
    final l = local(nowUtc);
    return DateTime.utc(l.year, l.month, l.day);
  }

  static DateTime dayOf(DateTime utc) {
    final l = local(utc);
    return DateTime.utc(l.year, l.month, l.day);
  }
}

abstract final class Fmt {
  static final NumberFormat _money = NumberFormat.decimalPattern('ru');

  static String time(DateTime utc) => DateFormat('HH:mm').format(ClubTime.local(utc));

  static String weekdayShort(DateTime day) =>
      DateFormat('EE', 'ru').format(day).replaceAll('.', '');

  static String dayMonth(DateTime utc) => DateFormat('d MMMM', 'ru').format(ClubTime.local(utc));

  static String dayMonthShort(DateTime utc) =>
      DateFormat('d MMM', 'ru').format(ClubTime.local(utc)).replaceAll('.', '');

  /// "Сегодня", "Завтра" or "пятница, 31 октября".
  static String dayTitle(DateTime day, DateTime nowUtc) {
    final today = ClubTime.today(nowUtc);
    final diff = day.difference(today).inDays;
    if (diff == 0) {
      return 'Сегодня';
    }
    if (diff == 1) {
      return 'Завтра';
    }
    return DateFormat('EEEE, d MMMM', 'ru').format(day);
  }

  static String dateRange(DateTime startUtc, DateTime? endUtc) {
    final start = ClubTime.local(startUtc);
    if (endUtc == null) {
      return DateFormat('d MMMM, EEEE', 'ru').format(start);
    }
    final end = ClubTime.local(endUtc);
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return DateFormat('d MMMM, EEEE', 'ru').format(start);
    }
    if (start.month == end.month) {
      return '${start.day}–${DateFormat('d MMMM', 'ru').format(end)}';
    }
    return '${DateFormat('d MMMM', 'ru').format(start)} – ${DateFormat('d MMMM', 'ru').format(end)}';
  }

  static String money(int rub) => '${_money.format(rub)} ₽';

  static String number(int n) => _money.format(n);

  static String price(int? rub) {
    if (rub == null) {
      return 'Цена уточняется';
    }
    if (rub <= 0) {
      return 'Бесплатно';
    }
    return money(rub);
  }

  /// "1 место", "3 места", "5 мест".
  static String seats(int n) => '$n ${plural(n, 'место', 'места', 'мест')}';

  static String plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) {
      return one;
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }
    return many;
  }
}

/// Sheet titles often start with an emoji ("🥊 BOXING DVOR"). The app shows
/// it as an icon tile and keeps the title text clean.
({String? emoji, String text}) splitTitleEmoji(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return (emoji: null, text: trimmed);
  }
  final first = trimmed.characters.first;
  if (_letterOrDigit.hasMatch(first) || first.trim().isEmpty) {
    return (emoji: null, text: trimmed);
  }
  final rest = trimmed.characters.skip(1).toString().trim();
  return (emoji: rest.isEmpty ? null : first, text: rest.isEmpty ? trimmed : rest);
}

final RegExp _letterOrDigit = RegExp(r'^[\p{L}\p{N}"«(]', unicode: true);

/// Same Telegram nick, ignoring @ and letter case.
bool sameTelegramNick(String? left, String? right) {
  final a = _bareNick(left);
  final b = _bareNick(right);
  if (a == null || b == null) {
    return false;
  }
  return a.toLowerCase() == b.toLowerCase();
}

String? _bareNick(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final bare = trimmed.startsWith('@') ? trimmed.substring(1).trim() : trimmed;
  return bare.isEmpty ? null : bare;
}
