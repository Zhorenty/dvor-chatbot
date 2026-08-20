import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:intl/intl.dart';

/// Dashboard layout for the `FUNNEL` sheet: KPI cards, tables, and chart specs.
abstract final class GoogleSheetsFunnelDashboard {
  static const String defaultSheetTitle = 'FUNNEL';
  static const String analyticsSheetTitle = 'АНАЛИТИКА';
  static const String noblesSheetTitle = 'ДВОРЯНЕ';
  static const String recentActionsSheetTitle = 'ДЕЙСТВИЯ';
  static const int columnCount = 12;

  static const GoogleSheetsRgb ink = GoogleSheetsRgb(0.12, 0.16, 0.14);
  static const GoogleSheetsRgb paper = GoogleSheetsRgb(0.98, 0.97, 0.94);
  static const GoogleSheetsRgb header = GoogleSheetsRgb(0.12, 0.23, 0.18);
  static const GoogleSheetsRgb headerText = GoogleSheetsRgb(0.96, 0.95, 0.91);
  static const GoogleSheetsRgb muted = GoogleSheetsRgb(0.35, 0.40, 0.37);
  static const GoogleSheetsRgb kpiA = GoogleSheetsRgb(0.88, 0.93, 0.88);
  static const GoogleSheetsRgb kpiB = GoogleSheetsRgb(0.94, 0.91, 0.84);
  static const GoogleSheetsRgb kpiC = GoogleSheetsRgb(0.86, 0.91, 0.94);
  static const GoogleSheetsRgb section = GoogleSheetsRgb(0.22, 0.38, 0.30);
  static const GoogleSheetsRgb tableHead = GoogleSheetsRgb(0.83, 0.88, 0.83);

  static final DateFormat _stamp = DateFormat('dd.MM.yyyy HH:mm');

  static GoogleSheetsDashboard build(
    FunnelAnalytics analytics, {
    String sheetTitle = defaultSheetTitle,
  }) {
    final sheet = _FunnelSheetBuilder();
    sheet.paintSheet();
    sheet.writeHeader(analytics);
    sheet.writeKpis(analytics);
    sheet.writeFunnel(analytics);
    sheet.writeDynamics(analytics);
    sheet.writeWhereNow(analytics);
    sheet.writeQuiz(analytics);
    sheet.writeFeedback(analytics);
    sheet.writeNudges(analytics);
    sheet.writeComments(analytics);
    return GoogleSheetsDashboard(
      sheetTitle: sheetTitle,
      rows: sheet.rows,
      charts: sheet.charts.where((chart) => chart.hasData).toList(growable: false),
      styles: sheet.styles,
      bandedTables: sheet.bandedTables,
      columnWidthsPx: const <int>[250, 110, 120, 250, 110, 120, 200, 90, 90, 90, 90, 180],
    );
  }
}

final class _FunnelSheetBuilder {
  final List<List<Object?>> rows = <List<Object?>>[];
  final List<GoogleSheetsRangeStyle> styles = <GoogleSheetsRangeStyle>[];
  final List<GoogleSheetsBandedTable> bandedTables = <GoogleSheetsBandedTable>[];
  final List<GoogleSheetsChart> charts = <GoogleSheetsChart>[];

  int get nextRow => rows.length;

  void paintSheet() {
    styles.add(
      const GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: 90,
        startColumn: 0,
        endColumnExclusive: GoogleSheetsFunnelDashboard.columnCount,
        background: GoogleSheetsFunnelDashboard.paper,
        foreground: GoogleSheetsFunnelDashboard.ink,
        fontSize: 10,
        wrap: true,
      ),
    );
  }

  void writeHeader(FunnelAnalytics analytics) {
    final stamp = GoogleSheetsFunnelDashboard._stamp.format(analytics.generatedAt.toLocal());
    _add(
      <Object?>['DVOR · Воронка', '', '', '', '', '', '', '', '', '', '', 'Срез $stamp'],
    );
    styles.add(
      const GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: 1,
        startColumn: 0,
        endColumnExclusive: 11,
        background: GoogleSheetsFunnelDashboard.header,
        foreground: GoogleSheetsFunnelDashboard.headerText,
        bold: true,
        fontSize: 18,
        merge: true,
        verticalAlignment: 'MIDDLE',
      ),
    );
    styles.add(
      const GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: 1,
        startColumn: 11,
        endColumnExclusive: GoogleSheetsFunnelDashboard.columnCount,
        background: GoogleSheetsFunnelDashboard.header,
        foreground: GoogleSheetsFunnelDashboard.headerText,
        bold: true,
        fontSize: 11,
        horizontalAlignment: 'RIGHT',
        verticalAlignment: 'MIDDLE',
      ),
    );
    _add(
      const <Object?>[
        'Как новичок доходит до первой тренировки. Лист обновляет бот — руками не править.',
      ],
    );
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: 1,
        endRowExclusive: 2,
        startColumn: 0,
        endColumnExclusive: GoogleSheetsFunnelDashboard.columnCount,
        foreground: GoogleSheetsFunnelDashboard.muted,
        fontSize: 10,
        merge: true,
      ),
    );
    _blank();
  }

  void writeKpis(FunnelAnalytics analytics) {
    final labelRow = nextRow;
    _add(
      const <Object?>[
        'Start всего',
        '',
        'В воронке',
        '',
        'Первая тренировка',
        '',
        'Дошли за 21 день',
        '',
        'Среднее до тренировки',
        '',
        'Фидбек, ответы',
        '',
      ],
    );
    final valueRow = nextRow;
    final activationRate = _ratioOrDash(analytics.activationRate21Days);
    final daysToTraining = _daysOrDash(analytics.avgTimeToValueDays);
    final feedbackRate = _ratioOrDash(analytics.feedbackResponseRate);
    _add(
      <Object?>[
        analytics.startedUsersTotal,
        '',
        analytics.funnelUsers,
        '',
        analytics.activationsTotal,
        '',
        activationRate,
        '',
        daysToTraining,
        '',
        feedbackRate,
        '',
      ],
    );
    final hintRow = nextRow;
    _add(
      <Object?>[
        'legacy без квиза: ${analytics.legacyUsers}',
        '',
        'новых Start 7д: ${analytics.startedLast7Days}',
        '',
        'активации 7д: ${analytics.activationsLast7Days}',
        '',
        'с карты до записи: ${_percentLabel(analytics.mapToActivationRate)}',
        '',
        'пауза «нужно время»: ${analytics.snoozeActiveNow}',
        '',
        'запросов: ${analytics.feedbackRequestsSent}',
        '',
      ],
    );
    const cards = <(int, GoogleSheetsRgb)>[
      (0, GoogleSheetsFunnelDashboard.kpiA),
      (2, GoogleSheetsFunnelDashboard.kpiB),
      (4, GoogleSheetsFunnelDashboard.kpiC),
      (6, GoogleSheetsFunnelDashboard.kpiA),
      (8, GoogleSheetsFunnelDashboard.kpiB),
      (10, GoogleSheetsFunnelDashboard.kpiC),
    ];
    for (final card in cards) {
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: labelRow,
          endRowExclusive: labelRow + 1,
          startColumn: card.$1,
          endColumnExclusive: card.$1 + 2,
          background: card.$2,
          foreground: GoogleSheetsFunnelDashboard.muted,
          bold: true,
          fontSize: 9,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          wrap: true,
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: valueRow,
          endRowExclusive: valueRow + 1,
          startColumn: card.$1,
          endColumnExclusive: card.$1 + 2,
          background: card.$2,
          foreground: GoogleSheetsFunnelDashboard.ink,
          bold: true,
          fontSize: 18,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          numberFormatType: _kpiNumberType(card.$1, activationRate, daysToTraining, feedbackRate),
          numberFormatPattern: _kpiNumberPattern(card.$1),
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: hintRow,
          endRowExclusive: hintRow + 1,
          startColumn: card.$1,
          endColumnExclusive: card.$1 + 2,
          background: card.$2,
          foreground: GoogleSheetsFunnelDashboard.muted,
          fontSize: 9,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          wrap: true,
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: labelRow,
          endRowExclusive: hintRow + 1,
          startColumn: card.$1,
          endColumnExclusive: card.$1 + 2,
          borders: true,
        ),
      );
    }
    _blank();
  }

  void writeFunnel(FunnelAnalytics analytics) {
    _section('Путь новичка');
    _subtitle(
      'Пропуск квиза сразу ведёт на шаг 4, поэтому шаги 2–3 могут быть меньше шага 4.',
    );
    _add(const <Object?>['Шаг', 'Люди', 'От старта', 'От предыдущего']);
    final headerRow = nextRow - 1;
    final started = analytics.funnelUsers;
    final steps = <(String, int)>[
      ('1. Начали квиз', analytics.funnelUsers),
      ('2. Что сейчас важнее', analytics.quizGoalAnsweredCount),
      ('3. Опыт', analytics.quizExperienceAnsweredCount),
      ('4. Формат и карта клуба', analytics.trackChosenCount),
      ('5. Первая тренировка', analytics.activationsTotal),
    ];
    final firstData = nextRow;
    var previous = started;
    for (final step in steps) {
      _add(
        <Object?>[
          step.$1,
          step.$2,
          _ratioOrDash(started <= 0 ? null : step.$2 / started),
          _ratioOrDash(previous <= 0 ? null : step.$2 / previous),
        ],
      );
      previous = step.$2;
    }
    _table(headerRow, nextRow, 0, 4);
    _percentColumns(firstData, nextRow, const <int>[2, 3]);
    charts.add(
      GoogleSheetsChart(
        title: 'Путь новичка',
        kind: GoogleSheetsChartKind.bar,
        headerRow: headerRow,
        endRowExclusive: nextRow,
        labelColumn: 0,
        valueColumn: 1,
        anchorRow: headerRow,
        anchorColumn: 5,
        widthPixels: 560,
        heightPixels: 280,
        legendPosition: 'NO_LEGEND',
      ),
    );
    _blank();
  }

  void writeDynamics(FunnelAnalytics analytics) {
    _section('Старт и активации');
    _add(const <Object?>['Период', 'Start', 'Активации']);
    final headerRow = nextRow - 1;
    _add(<Object?>['7 дней', analytics.startedLast7Days, analytics.activationsLast7Days]);
    _add(<Object?>['30 дней', analytics.startedLast30Days, analytics.activationsLast30Days]);
    _table(headerRow, nextRow, 0, 3);
    charts.add(
      GoogleSheetsChart(
        title: '7 / 30 дней',
        kind: GoogleSheetsChartKind.column,
        headerRow: headerRow,
        endRowExclusive: nextRow,
        labelColumn: 0,
        valueColumn: 1,
        anchorRow: headerRow,
        anchorColumn: 4,
        widthPixels: 420,
        heightPixels: 220,
      ),
    );
    charts.add(
      GoogleSheetsChart(
        title: 'Активации 7 / 30 дней',
        kind: GoogleSheetsChartKind.column,
        headerRow: headerRow,
        endRowExclusive: nextRow,
        labelColumn: 0,
        valueColumn: 2,
        anchorRow: headerRow,
        anchorColumn: 8,
        widthPixels: 360,
        heightPixels: 220,
        legendPosition: 'NO_LEGEND',
      ),
    );
    _blank();
  }

  void writeWhereNow(FunnelAnalytics analytics) {
    _section('Где люди сейчас  ·  Откуда пришли');
    final headerRow = nextRow;
    _add(const <Object?>['Сейчас на шаге', 'Люди', '', 'Источник', 'Люди']);
    final phases = _ordered(
      analytics.phaseCounts,
      const <String>[
        'phase1_quiz',
        'phase1_track',
        'phase1_map',
        'phase2_activation',
        'paused',
        'phase3_integration',
        'phase4_completion',
        'completed',
        'returning',
        'not_started',
        'legacy_skipped',
        'null',
      ],
      _phaseLabel,
    );
    final entries = _ordered(
      analytics.entryTypeCounts,
      const <String>['group', 'referral', 'cold', 'returning', 'legacy', 'unknown'],
      _entryLabel,
    );
    final firstData = nextRow;
    final height = phases.length > entries.length ? phases.length : entries.length;
    for (var index = 0; index < height; index++) {
      final phase = index < phases.length ? phases[index] : null;
      final entry = index < entries.length ? entries[index] : null;
      _add(
        <Object?>[
          phase?.$1 ?? '',
          phase?.$2 ?? '',
          '',
          entry?.$1 ?? '',
          entry?.$2 ?? '',
        ],
      );
    }
    _table(headerRow, firstData + phases.length, 0, 2);
    _table(headerRow, firstData + entries.length, 3, 5);
    if (phases.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Где сейчас',
          kind: GoogleSheetsChartKind.bar,
          headerRow: headerRow,
          endRowExclusive: firstData + phases.length,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: firstData + height,
          anchorColumn: 0,
          widthPixels: 520,
          heightPixels: 280,
          legendPosition: 'NO_LEGEND',
        ),
      );
    }
    if (entries.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Откуда пришли',
          kind: GoogleSheetsChartKind.pie,
          headerRow: headerRow,
          endRowExclusive: firstData + entries.length,
          labelColumn: 3,
          valueColumn: 4,
          anchorRow: firstData + height,
          anchorColumn: 6,
          widthPixels: 420,
          heightPixels: 280,
          pieHole: 0.45,
        ),
      );
    }
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
  }

  void writeQuiz(FunnelAnalytics analytics) {
    _section('Что выбрали в квизе');
    final headerRow = nextRow;
    _add(const <Object?>['Цель', 'Люди', '', 'Опыт', 'Люди', '', 'Формат старта', 'Люди']);
    final goals = _ordered(
      analytics.quizGoalCounts,
      const <String>['form_strength', 'endurance_run', 'outdoor_hikes', 'unknown'],
      _goalLabel,
    );
    final experience = _ordered(
      analytics.quizExperienceCounts,
      const <String>['beginner', 'returning', 'regular'],
      _experienceLabel,
    );
    final tracks = _ordered(
      analytics.trackCounts,
      const <String>['one_off', 'outdoor'],
      _trackLabel,
    );
    final firstData = nextRow;
    final height = [goals.length, experience.length, tracks.length].reduce(
      (a, b) => a > b ? a : b,
    );
    for (var index = 0; index < height; index++) {
      _add(
        <Object?>[
          index < goals.length ? goals[index].$1 : '',
          index < goals.length ? goals[index].$2 : '',
          '',
          index < experience.length ? experience[index].$1 : '',
          index < experience.length ? experience[index].$2 : '',
          '',
          index < tracks.length ? tracks[index].$1 : '',
          index < tracks.length ? tracks[index].$2 : '',
        ],
      );
    }
    _table(headerRow, firstData + goals.length, 0, 2);
    _table(headerRow, firstData + experience.length, 3, 5);
    _table(headerRow, firstData + tracks.length, 6, 8);
    if (goals.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Цель',
          kind: GoogleSheetsChartKind.bar,
          headerRow: headerRow,
          endRowExclusive: firstData + goals.length,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: firstData + height,
          anchorColumn: 0,
          widthPixels: 360,
          heightPixels: 220,
          legendPosition: 'NO_LEGEND',
        ),
      );
    }
    if (experience.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Опыт',
          kind: GoogleSheetsChartKind.pie,
          headerRow: headerRow,
          endRowExclusive: firstData + experience.length,
          labelColumn: 3,
          valueColumn: 4,
          anchorRow: firstData + height,
          anchorColumn: 4,
          widthPixels: 320,
          heightPixels: 220,
          pieHole: 0.4,
        ),
      );
    }
    if (tracks.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Формат',
          kind: GoogleSheetsChartKind.pie,
          headerRow: headerRow,
          endRowExclusive: firstData + tracks.length,
          labelColumn: 6,
          valueColumn: 7,
          anchorRow: firstData + height,
          anchorColumn: 8,
          widthPixels: 300,
          heightPixels: 220,
          pieHole: 0.4,
        ),
      );
    }
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
  }

  void writeFeedback(FunnelAnalytics analytics) {
    _section(
      'Фидбек  ·  ответов ${analytics.feedbackResponses} из ${analytics.feedbackRequestsSent}'
      '  ·  пропусков ${analytics.feedbackSkipped}'
      '  ·  комментариев ${analytics.feedbackCommentsCount}',
    );
    _add(const <Object?>['Оценка', 'Ответов', '', 'Занятие', 'Отзывов', '👍', '🙂', '👎']);
    final headerRow = nextRow - 1;
    final ratings = _ordered(
      analytics.feedbackRatingCounts,
      const <String>['great', 'ok', 'weak', 'skipped'],
      _ratingLabel,
    );
    final sessions = analytics.topFeedbackSessions;
    final firstData = nextRow;
    final height = ratings.length > sessions.length ? ratings.length : sessions.length;
    for (var index = 0; index < height; index++) {
      final rating = index < ratings.length ? ratings[index] : null;
      final session = index < sessions.length ? sessions[index] : null;
      _add(
        <Object?>[
          rating?.$1 ?? '',
          rating?.$2 ?? '',
          '',
          session?.trainingTitle ?? '',
          session?.responses ?? '',
          session?.greatCount ?? '',
          session?.okCount ?? '',
          session?.weakCount ?? '',
        ],
      );
    }
    _table(headerRow, firstData + ratings.length, 0, 2);
    _table(headerRow, firstData + sessions.length, 3, 8);
    if (ratings.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Оценки',
          kind: GoogleSheetsChartKind.pie,
          headerRow: headerRow,
          endRowExclusive: firstData + ratings.length,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: firstData + height,
          anchorColumn: 8,
          widthPixels: 300,
          heightPixels: 220,
          pieHole: 0.45,
        ),
      );
    }
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
    _blank();
  }

  void writeNudges(FunnelAnalytics analytics) {
    _section('Напоминания · каждое уходит один раз');
    _add(const <Object?>['Напоминание', 'Людям']);
    final headerRow = nextRow - 1;
    final nudges = _ordered(
      analytics.nudgeKeyCounts,
      const <String>[
        'p1_30m',
        'p1_2h',
        'p1_6h',
        'p1_24h',
        'p2_d2',
        'p2_d5',
        'p2_d7',
        'group_invite_1',
        'group_invite_2',
        'group_invite_3',
      ],
      _nudgeLabel,
    );
    if (nudges.isEmpty) {
      _add(const <Object?>['Пока нет', 0]);
    } else {
      for (final nudge in nudges) {
        _add(<Object?>[nudge.$1, nudge.$2]);
      }
    }
    _table(headerRow, nextRow, 0, 2);
    if (nudges.any((item) => item.$2 > 0)) {
      charts.add(
        GoogleSheetsChart(
          title: 'Напоминания',
          kind: GoogleSheetsChartKind.bar,
          headerRow: headerRow,
          endRowExclusive: nextRow,
          labelColumn: 0,
          valueColumn: 1,
          anchorRow: headerRow,
          anchorColumn: 3,
          widthPixels: 560,
          heightPixels: 280,
          legendPosition: 'NO_LEGEND',
        ),
      );
    }
    _blank();
  }

  void writeComments(FunnelAnalytics analytics) {
    _section('Последние комментарии · анонимно');
    _add(const <Object?>['Когда', 'Оценка', 'Занятие', 'Комментарий']);
    final headerRow = nextRow - 1;
    if (analytics.recentFeedbackComments.isEmpty) {
      _add(const <Object?>['Пока нет', '', '', '']);
    } else {
      for (final item in analytics.recentFeedbackComments) {
        final comment = (item.comment ?? '').trim();
        final short = comment.length > 180 ? '${comment.substring(0, 177)}…' : comment;
        _add(
          <Object?>[
            GoogleSheetsFunnelDashboard._stamp.format(item.submittedAt.toLocal()),
            _ratingLabel(item.rating),
            item.trainingTitle,
            short,
          ],
        );
      }
    }
    _table(headerRow, nextRow, 0, 4);
  }

  void _section(String title) {
    final row = nextRow;
    _add(<Object?>[title]);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: row,
        endRowExclusive: row + 1,
        startColumn: 0,
        endColumnExclusive: GoogleSheetsFunnelDashboard.columnCount,
        background: GoogleSheetsFunnelDashboard.section,
        foreground: GoogleSheetsFunnelDashboard.headerText,
        bold: true,
        fontSize: 12,
        merge: true,
        verticalAlignment: 'MIDDLE',
      ),
    );
  }

  void _subtitle(String text) {
    final row = nextRow;
    _add(<Object?>[text]);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: row,
        endRowExclusive: row + 1,
        startColumn: 0,
        endColumnExclusive: GoogleSheetsFunnelDashboard.columnCount,
        foreground: GoogleSheetsFunnelDashboard.muted,
        fontSize: 9,
        merge: true,
        wrap: true,
      ),
    );
  }

  void _table(int headerRow, int endRowExclusive, int startColumn, int endColumnExclusive) {
    if (endRowExclusive <= headerRow || endColumnExclusive <= startColumn) {
      return;
    }
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: headerRow,
        endRowExclusive: headerRow + 1,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
        background: GoogleSheetsFunnelDashboard.tableHead,
        foreground: GoogleSheetsFunnelDashboard.ink,
        bold: true,
        fontSize: 10,
        verticalAlignment: 'MIDDLE',
      ),
    );
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: headerRow,
        endRowExclusive: endRowExclusive,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
        borders: true,
        innerBorders: true,
      ),
    );
    bandedTables.add(
      GoogleSheetsBandedTable(
        startRow: headerRow,
        endRowExclusive: endRowExclusive,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
      ),
    );
  }

  void _percentColumns(int startRow, int endRowExclusive, List<int> columns) {
    for (final column in columns) {
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: startRow,
          endRowExclusive: endRowExclusive,
          startColumn: column,
          endColumnExclusive: column + 1,
          numberFormatType: 'PERCENT',
          numberFormatPattern: '0.0%',
        ),
      );
    }
  }

  void _blank() => _add(const <Object?>[]);

  void _add(List<Object?> cells) {
    final row = List<Object?>.filled(GoogleSheetsFunnelDashboard.columnCount, '');
    final limit = cells.length < GoogleSheetsFunnelDashboard.columnCount
        ? cells.length
        : GoogleSheetsFunnelDashboard.columnCount;
    for (var index = 0; index < limit; index++) {
      row[index] = cells[index];
    }
    rows.add(row);
  }

  Object _ratioOrDash(double? value) => value ?? '—';

  Object _daysOrDash(double? value) => value ?? '—';

  String? _kpiNumberType(
    int startColumn,
    Object activationRate,
    Object daysToTraining,
    Object feedbackRate,
  ) {
    if (startColumn == 6 && activationRate is num) {
      return 'PERCENT';
    }
    if (startColumn == 8 && daysToTraining is num) {
      return 'NUMBER';
    }
    if (startColumn == 10 && feedbackRate is num) {
      return 'PERCENT';
    }
    return null;
  }

  String? _kpiNumberPattern(int startColumn) {
    if (startColumn == 6 || startColumn == 10) {
      return '0.0%';
    }
    if (startColumn == 8) {
      return '0.0" дн."';
    }
    return null;
  }

  String _percentLabel(double? value) {
    if (value == null) {
      return '—';
    }
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  List<(String, int)> _ordered(
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

  String _phaseLabel(String raw) => switch (raw) {
        'legacy_skipped' => 'старые, без квиза',
        'phase1_quiz' => 'квиз: цель',
        'phase1_track' => 'квиз: формат',
        'phase1_map' => 'карта клуба',
        'phase2_activation' => 'ждут первую запись',
        'phase3_integration' => 'уже были на тренировке',
        'phase4_completion' => 'завершение',
        'completed' => 'воронка закрыта',
        'paused' => 'пауза',
        'returning' => 'вернулись позже',
        'not_started' => 'ещё не начали',
        'null' => 'фаза не проставлена',
        _ => raw,
      };

  String _entryLabel(String raw) => switch (raw) {
        'group' => 'из группы',
        'cold' => 'напрямую в личку',
        'referral' => 'рефералка',
        'returning' => 'вернулись',
        'legacy' => 'были до воронки',
        'unknown' => 'не указан',
        _ => raw,
      };

  String _goalLabel(String raw) => switch (raw) {
        'form_strength' => 'форма / сила',
        'endurance_run' => 'выносливость / бег',
        'outdoor_hikes' => 'outdoor / походы',
        'unknown' => 'пока не знаю',
        _ => raw,
      };

  String _experienceLabel(String raw) => switch (raw) {
        'beginner' => 'новичок',
        'returning' => 'был перерыв',
        'regular' => 'регулярно',
        _ => raw,
      };

  String _trackLabel(String raw) => switch (raw) {
        'one_off' => 'разовая тренировка',
        'outdoor' => 'outdoor / походы',
        _ => raw,
      };

  String _ratingLabel(String raw) => switch (raw) {
        'great' => 'отлично',
        'ok' => 'нормально',
        'weak' => 'слабо',
        'skipped' => 'пропуск',
        _ => raw,
      };

  String _nudgeLabel(String raw) => switch (raw) {
        'p1_30m' => '30 мин: дожать квиз',
        'p1_2h' => '2 часа: дожать квиз',
        'p1_6h' => '6 часов: помощь',
        'p1_24h' => 'сутки: расписание',
        'p2_d2' => 'день 2: записаться',
        'p2_d5' => 'день 5: другой формат',
        'p2_d7' => 'день 7: запись / поддержка',
        'group_invite_1' => 'группа: первое',
        'group_invite_2' => 'группа: второе',
        'group_invite_3' => 'группа: третье',
        _ => raw,
      };
}
