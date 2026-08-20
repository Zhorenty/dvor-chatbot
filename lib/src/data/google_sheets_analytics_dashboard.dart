import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_sheet_builder.dart';
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:intl/intl.dart';

/// Dashboard for the `АНАЛИТИКА` sheet: bookings, loyalty, subscriptions, economy.
abstract final class GoogleSheetsAnalyticsDashboard {
  static const String defaultSheetTitle = GoogleSheetsFunnelDashboard.analyticsSheetTitle;

  static GoogleSheetsDashboard build({
    required BookingAnalytics bookings,
    required LoyaltyAnalytics loyalty,
    required SubscriptionAnalytics subscriptions,
    required EconomicSummary currentWeek,
    required EconomicSummary currentMonth,
    String sheetTitle = defaultSheetTitle,
  }) {
    final sheet = GoogleSheetsSheetBuilder();
    sheet.writeBanner(
      title: 'DVOR · Аналитика',
      generatedAt: bookings.generatedAt,
      subtitle: 'Бронирования, бонусы, абонементы и экономика. '
          'Лист обновляет бот — руками не править.',
    );
    _writeBookingKpis(sheet, bookings);
    _writeBookings(sheet, bookings);
    _writeLoyalty(sheet, loyalty);
    _writeSubscriptions(sheet, subscriptions);
    _writeEconomy(sheet, currentWeek, currentMonth);
    return sheet.toDashboard(
      sheetTitle: sheetTitle,
      columnWidthsPx: const <int>[220, 120, 140, 220, 110, 120, 200, 110, 110, 90, 90, 160],
      minPaintRows: 120,
    );
  }

  static void _writeBookingKpis(GoogleSheetsSheetBuilder sheet, BookingAnalytics bookings) {
    final conversion = sheet.ratioOrDash(bookings.conversionRate30Days);
    sheet.writeKpiRow(
      <GoogleSheetsKpiCard>[
        GoogleSheetsKpiCard(
          label: 'Всего записей',
          value: bookings.totalBookings,
          hint: 'все статусы',
        ),
        GoogleSheetsKpiCard(
          label: 'Создано 7д',
          value: bookings.createdLast7Days,
        ),
        GoogleSheetsKpiCard(
          label: 'Создано 30д',
          value: bookings.createdLast30Days,
        ),
        GoogleSheetsKpiCard(
          label: 'Уникальные с подтверждёнными',
          value: bookings.uniqueUsersWithConfirmed,
        ),
        GoogleSheetsKpiCard(
          label: 'С промокодом',
          value: bookings.promoCodeBookingsCount,
        ),
        GoogleSheetsKpiCard(
          label: 'Конверсия 30д',
          value: conversion,
          numberFormatType: conversion is num ? 'PERCENT' : null,
          numberFormatPattern: conversion is num ? '0.0%' : null,
        ),
      ],
    );
  }

  static void _writeBookings(GoogleSheetsSheetBuilder sheet, BookingAnalytics bookings) {
    sheet.section('Бронирования');
    sheet.add(
      const <Object?>[
        'Сейчас',
        'Записей',
        '',
        'Период',
        'Создано',
        'Подтверждено',
        'Отменено',
      ],
    );
    final headerRow = sheet.nextRow - 1;
    final nowRows = <(String, int)>[
      ('ожидает оплату', bookings.pendingPaymentCount),
      ('на проверке', bookings.paymentSubmittedCount),
      ('предстоящие подтверждённые', bookings.upcomingConfirmedCount),
      ('прошедшие подтверждённые', bookings.pastConfirmedCount),
    ];
    final dynamics = <(String, int, int, int)>[
      (
        '7 дней',
        bookings.createdLast7Days,
        bookings.confirmedLast7Days,
        bookings.cancelledLast7Days,
      ),
      (
        '30 дней',
        bookings.createdLast30Days,
        bookings.confirmedLast30Days,
        bookings.cancelledLast30Days,
      ),
    ];
    final firstData = sheet.nextRow;
    final height = nowRows.length > dynamics.length ? nowRows.length : dynamics.length;
    for (var index = 0; index < height; index++) {
      final now = index < nowRows.length ? nowRows[index] : null;
      final period = index < dynamics.length ? dynamics[index] : null;
      sheet.add(
        <Object?>[
          now?.$1 ?? '',
          now?.$2 ?? '',
          '',
          period?.$1 ?? '',
          period?.$2 ?? '',
          period?.$3 ?? '',
          period?.$4 ?? '',
        ],
      );
    }
    sheet.table(headerRow, firstData + nowRows.length, 0, 2);
    sheet.table(headerRow, firstData + dynamics.length, 3, 7);
    sheet.charts.add(
      GoogleSheetsChart(
        title: '7 / 30 дней: создано и подтверждено',
        kind: GoogleSheetsChartKind.column,
        headerRow: headerRow,
        endRowExclusive: firstData + dynamics.length,
        labelColumn: 3,
        valueColumn: 4,
        additionalValueColumns: const <int>[5],
        anchorRow: firstData + height,
        anchorColumn: 0,
        widthPixels: 480,
        heightPixels: 240,
      ),
    );
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();

    sheet.add(const <Object?>['Статус', 'Записей', '', 'Категория', 'Подтверждённые']);
    final mixHeader = sheet.nextRow - 1;
    final statuses = _ordered(
      bookings.statusCounts,
      const <String>[
        'pending_payment',
        'payment_submitted',
        'partial_paid',
        'paid',
        'free_training',
        'payment_rejected',
        'cancelled',
      ],
      _bookingStatusLabel,
    );
    final categories = _ordered(
      bookings.confirmedByCategory,
      const <String>['trainings', 'hikes', 'trails'],
      _activityCategoryLabel,
    );
    final mixFirst = sheet.nextRow;
    final mixHeight = statuses.length > categories.length ? statuses.length : categories.length;
    if (mixHeight == 0) {
      sheet.add(const <Object?>['Пока нет', 0, '', 'Пока нет', 0]);
    } else {
      for (var index = 0; index < mixHeight; index++) {
        final status = index < statuses.length ? statuses[index] : null;
        final category = index < categories.length ? categories[index] : null;
        sheet.add(
          <Object?>[
            status?.$1 ?? '',
            status?.$2 ?? '',
            '',
            category?.$1 ?? '',
            category?.$2 ?? '',
          ],
        );
      }
    }
    final statusEnd = mixFirst + (statuses.isEmpty ? 1 : statuses.length);
    final categoryEnd = mixFirst + (categories.isEmpty ? 1 : categories.length);
    sheet.table(mixHeader, statusEnd, 0, 2);
    sheet.table(mixHeader, categoryEnd, 3, 5);
    if (statuses.any((item) => item.$2 > 0)) {
      sheet.charts.add(
        GoogleSheetsChart(
          title: 'Статусы',
          kind: GoogleSheetsChartKind.pie,
          headerRow: mixHeader,
          endRowExclusive: mixFirst + statuses.length,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: mixFirst + mixHeight,
          anchorColumn: 6,
          widthPixels: 320,
          heightPixels: 240,
          pieHole: 0.45,
        ),
      );
    }
    if (categories.any((item) => item.$2 > 0)) {
      sheet.charts.add(
        GoogleSheetsChart(
          title: 'Подтверждённые по категориям',
          kind: GoogleSheetsChartKind.bar,
          headerRow: mixHeader,
          endRowExclusive: mixFirst + categories.length,
          labelColumn: 3,
          valueColumn: 4,
          anchorRow: mixFirst + mixHeight,
          anchorColumn: 0,
          widthPixels: 360,
          heightPixels: 220,
          legendPosition: 'NO_LEGEND',
        ),
      );
    }
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
  }

  static void _writeLoyalty(GoogleSheetsSheetBuilder sheet, LoyaltyAnalytics loyalty) {
    sheet.section('Бонусы и рефералы');
    sheet.writeKpiRow(
      <GoogleSheetsKpiCard>[
        GoogleSheetsKpiCard(
          label: 'Стартовый доступен',
          value: loyalty.starterBonusAvailable,
        ),
        GoogleSheetsKpiCard(
          label: 'Стартовый использован',
          value: loyalty.starterBonusConsumed,
        ),
        GoogleSheetsKpiCard(
          label: 'Реферальные атрибуции',
          value: loyalty.referralAttributionsTotal,
        ),
        GoogleSheetsKpiCard(
          label: 'Атрибуции 30д',
          value: loyalty.referralAttributionsLast30Days,
        ),
        GoogleSheetsKpiCard(
          label: 'Бесплатных всего',
          value: loyalty.freeTrainingsTotal,
        ),
      ],
    );
    sheet.add(const <Object?>['Тип бесплатной', 'Записей']);
    final headerRow = sheet.nextRow - 1;
    final firstData = sheet.nextRow;
    final freeRows = <(String, int)>[
      ('стартовый бонус', loyalty.freeByStarterCount),
      ('реферальный бонус', loyalty.freeByReferralCount),
      ('каждая 5-я', loyalty.freeByEveryFifthCount),
    ];
    for (final row in freeRows) {
      sheet.add(<Object?>[row.$1, row.$2]);
    }
    sheet.table(headerRow, sheet.nextRow, 0, 2);
    if (freeRows.any((item) => item.$2 > 0)) {
      sheet.charts.add(
        GoogleSheetsChart(
          title: 'Структура бесплатных',
          kind: GoogleSheetsChartKind.pie,
          headerRow: headerRow,
          endRowExclusive: firstData + freeRows.length,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: headerRow,
          anchorColumn: 3,
          widthPixels: 360,
          heightPixels: 220,
          pieHole: 0.4,
        ),
      );
    }
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
  }

  static void _writeSubscriptions(
    GoogleSheetsSheetBuilder sheet,
    SubscriptionAnalytics subscriptions,
  ) {
    sheet.section('Абонементы');
    sheet.writeKpiRow(
      <GoogleSheetsKpiCard>[
        GoogleSheetsKpiCard(label: 'Активные', value: subscriptions.activeCount),
        GoogleSheetsKpiCard(
          label: 'Истекают ≤7д',
          value: subscriptions.expiringSoonCount,
        ),
        GoogleSheetsKpiCard(label: 'На проверке', value: subscriptions.pendingCount),
        GoogleSheetsKpiCard(
          label: 'Отменённые / отклонённые',
          value: subscriptions.cancelledOrRejectedCount,
        ),
        GoogleSheetsKpiCard(
          label: 'Approved всего',
          value: subscriptions.approvedTotal,
        ),
      ],
    );
  }

  static void _writeEconomy(
    GoogleSheetsSheetBuilder sheet,
    EconomicSummary currentWeek,
    EconomicSummary currentMonth,
  ) {
    sheet.section('Экономика');
    _writeEconomyPeriod(sheet, 'Текущая неделя', currentWeek);
    _writeEconomyPeriod(sheet, 'Текущий месяц', currentMonth);
  }

  static void _writeEconomyPeriod(
    GoogleSheetsSheetBuilder sheet,
    String title,
    EconomicSummary summary,
  ) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final endLabel = summary.period.endExclusive.subtract(const Duration(days: 1));
    final range =
        '${dateFormatter.format(summary.period.startInclusive)} — ${dateFormatter.format(endLabel)}';
    sheet.subtitle('$title · $range');
    sheet.writeKpiRow(
      <GoogleSheetsKpiCard>[
        GoogleSheetsKpiCard(
          label: 'Выручка',
          value: summary.totalRevenue,
          hint: summary.partialPaidBookingsCount > 0
              ? 'из них предоплат: ${summary.partialPaidRevenue}'
              : '',
          numberFormatType: 'NUMBER',
          numberFormatPattern: '#,##0',
        ),
        GoogleSheetsKpiCard(
          label: 'Оплачено',
          value: summary.paidBookingsCount,
          hint: summary.partialPaidBookingsCount > 0
              ? 'предоплат: ${summary.partialPaidBookingsCount}'
              : '',
        ),
        GoogleSheetsKpiCard(
          label: 'Средний чек',
          value: summary.averageCheck,
          numberFormatType: 'NUMBER',
          numberFormatPattern: '#,##0',
        ),
        GoogleSheetsKpiCard(
          label: 'Бесплатных',
          value: summary.freeBookingsCount,
          hint: _freeHint(summary),
        ),
        GoogleSheetsKpiCard(
          label: 'Без цены',
          value: summary.unknownPriceBookingsCount,
        ),
      ],
    );
    sheet.add(const <Object?>[
      'Категория',
      'Записей',
      'Выручка',
      '',
      'Мероприятие',
      'Записей',
      'Выручка'
    ]);
    final headerRow = sheet.nextRow - 1;
    final categories = summary.byCategory;
    final events = summary.byEvent;
    final firstData = sheet.nextRow;
    final height = [
      categories.isEmpty ? 1 : categories.length,
      events.isEmpty ? 1 : events.length,
    ].reduce((a, b) => a > b ? a : b);
    for (var index = 0; index < height; index++) {
      final category = index < categories.length ? categories[index] : null;
      final event = index < events.length ? events[index] : null;
      sheet.add(
        <Object?>[
          category == null
              ? (index == 0 && categories.isEmpty ? 'Пока нет' : '')
              : _activityCategoryLabel(category.category.name),
          category?.bookingsCount ?? (index == 0 && categories.isEmpty ? 0 : ''),
          category?.revenue ?? '',
          '',
          event == null ? (index == 0 && events.isEmpty ? 'Пока нет' : '') : event.eventTitle,
          event?.bookingsCount ?? (index == 0 && events.isEmpty ? 0 : ''),
          event?.revenue ?? '',
        ],
      );
    }
    final categoryEnd = firstData + (categories.isEmpty ? 1 : categories.length);
    final eventEnd = firstData + (events.isEmpty ? 1 : events.length);
    sheet.table(headerRow, categoryEnd, 0, 3);
    sheet.table(headerRow, eventEnd, 4, 7);
    if (categories.length >= 2) {
      sheet.charts.add(
        GoogleSheetsChart(
          title: '$title · категории',
          kind: GoogleSheetsChartKind.bar,
          headerRow: headerRow,
          endRowExclusive: firstData + categories.length,
          labelColumn: 0,
          valueColumn: 2,
          anchorRow: firstData + height,
          anchorColumn: 8,
          widthPixels: 320,
          heightPixels: 220,
          legendPosition: 'NO_LEGEND',
        ),
      );
    }
    sheet.blank();
    sheet.blank();
    sheet.blank();
    sheet.blank();
  }

  static String _freeHint(EconomicSummary summary) {
    final parts = <String>[];
    if (summary.regularFreeBookingsCount > 0) {
      parts.add('по цене: ${summary.regularFreeBookingsCount}');
    }
    if (summary.starterFreeBookingsCount > 0) {
      parts.add('стартовый: ${summary.starterFreeBookingsCount}');
    }
    if (summary.everyFifthFreeBookingsCount > 0) {
      parts.add('каждая 5-я: ${summary.everyFifthFreeBookingsCount}');
    }
    return parts.join(' · ');
  }

  static List<(String, int)> _ordered(
    Map<String, int> counts,
    List<String> order,
    String Function(String) labelOf,
  ) {
    final seen = <String>{};
    final items = <(String, int)>[];
    for (final key in order) {
      final value = counts[key];
      if (value == null) {
        continue;
      }
      seen.add(key);
      items.add((labelOf(key), value));
    }
    final remaining = counts.entries.where((entry) => !seen.contains(entry.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in remaining) {
      items.add((labelOf(entry.key), entry.value));
    }
    return items;
  }

  static String _bookingStatusLabel(String raw) => switch (raw) {
        'pending_payment' => 'ожидает оплату',
        'payment_submitted' => 'на проверке',
        'partial_paid' => 'предоплата',
        'paid' => 'оплачено',
        'free_training' => 'бесплатная',
        'payment_rejected' => 'оплата отклонена',
        'cancelled' => 'отменено',
        _ => raw,
      };

  static String _activityCategoryLabel(String raw) => switch (raw) {
        'trainings' => 'тренировки',
        'hikes' => 'походы',
        'trails' => 'трейлы',
        _ => raw,
      };
}
