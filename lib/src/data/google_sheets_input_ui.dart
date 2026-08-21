import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';

/// Manual input-sheet look: same palette as [GoogleSheetsFunnelDashboard], but
/// these tabs stay as CSV forms. The bot must never rewrite them on a timer.
abstract final class GoogleSheetsInputUi {
  static const String spreadsheetId = '1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q';
  static const String legendTitle = 'КАК ЗАПОЛНЯТЬ';
  static const String funnelTitle = 'FUNNEL';
  static const String coachesTitle = 'Тренерский штаб';
  static const int extraRows = 180;
  static const String statusHeader = 'статус';

  static const GoogleSheetsRgb paper = GoogleSheetsFunnelDashboard.paper;
  static const GoogleSheetsRgb ink = GoogleSheetsFunnelDashboard.ink;
  static const GoogleSheetsRgb headerTab = GoogleSheetsFunnelDashboard.header;
  static const GoogleSheetsRgb headerText = GoogleSheetsFunnelDashboard.headerText;
  static const GoogleSheetsRgb tableHead = GoogleSheetsFunnelDashboard.tableHead;
  static const GoogleSheetsRgb incomplete = GoogleSheetsRgb(0.94, 0.84, 0.74);
  static const GoogleSheetsRgb duplicate = GoogleSheetsRgb(0.93, 0.78, 0.76);

  static const List<GoogleSheetsInputSheetSpec> sheets = <GoogleSheetsInputSheetSpec>[
    trainings,
    hikes,
    trails,
    coaches,
    team,
    promoCodes,
  ];

  static const GoogleSheetsInputSheetSpec trainings = GoogleSheetsInputSheetSpec(
    gid: 0,
    title: 'Тренировки',
    tabColor: headerTab,
    requiredHeaders: <String>['название', 'место'],
    requiredDateHeaders: <String>['дата', 'время'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'название',
        aliases: <String>['title'],
        widthPx: 280,
        missingLabel: 'нет названия',
        note: 'Название. Пример: BOXING DVOR. Пустую строку бот пропускает.',
      ),
      GoogleSheetsInputColumn(
        header: 'дата',
        aliases: <String>['date'],
        widthPx: 110,
        kind: GoogleSheetsInputColumnKind.date,
        missingLabel: 'нет даты',
        note: 'Дата. Выбери в календаре. Формат 19.08.2026.',
      ),
      GoogleSheetsInputColumn(
        header: 'время',
        aliases: <String>['time'],
        widthPx: 90,
        kind: GoogleSheetsInputColumnKind.time,
        missingLabel: 'нет времени',
        note: 'Время начала. Пиши 19:30 или 8:30.',
      ),
      GoogleSheetsInputColumn(
        header: 'место',
        aliases: <String>['location', 'where', 'place'],
        widthPx: 240,
        wrap: true,
        missingLabel: 'нет места',
        note: 'Место. Пример: Стадион Кубань.',
      ),
      GoogleSheetsInputColumn(
        header: 'карта',
        aliases: <String>['location_url', 'location_link', 'maps_url', 'map_url'],
        widthPx: 220,
        kind: GoogleSheetsInputColumnKind.url,
        note: 'Ссылка на Яндекс Карты. Если пусто — бот ищет по месту.',
      ),
      GoogleSheetsInputColumn(
        header: 'тренер',
        aliases: <String>['coach', 'coaches', 'trainer', 'trainers', 'тренеры'],
        widthPx: 170,
        kind: GoogleSheetsInputColumnKind.coach,
        note: 'Имя из штаба или разовое. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'цена',
        aliases: <String>['price'],
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Цена в рублях, число. Можно 350 или 350₽.',
      ),
      GoogleSheetsInputColumn(
        header: 'лимит',
        aliases: <String>[
          'limit',
          'participants_limit',
          'participant_limit',
          'participants',
        ],
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Лимит мест, число.',
      ),
      GoogleSheetsInputColumn(
        header: 'заметки',
        aliases: <String>['notes', 'примечание'],
        widthPx: 360,
        wrap: true,
        note: 'Текст в карточке бота. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'тренеры_в_лимите',
        aliases: <String>[
          'include_trainers',
          'include_trainers_in_participants',
          'include_coaches_in_participants',
          'count_trainers_as_participants',
          'тренеры_в_участниках',
          'включать_тренеров_в_участников',
        ],
        widthPx: 150,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: считать тренеров в лимите мест. Не «пригласить тренера».',
      ),
      GoogleSheetsInputColumn(
        header: 'без_промокода',
        aliases: <String>[
          'promo_restricted',
          'no_promo',
          'restrict_promo',
          'without_promo',
          'без_скидок',
        ],
        widthPx: 140,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: промокод на эту тренировку не действует.',
      ),
      _statusColumn,
    ],
  );

  static const GoogleSheetsInputSheetSpec hikes = GoogleSheetsInputSheetSpec(
    gid: 294119056,
    title: 'Походы',
    tabColor: GoogleSheetsFunnelDashboard.section,
    requiredHeaders: <String>['название', 'дата_с', 'описание'],
    columns: outdoorColumns,
  );

  static const GoogleSheetsInputSheetSpec trails = GoogleSheetsInputSheetSpec(
    gid: 1220729038,
    title: 'Трейлы',
    tabColor: GoogleSheetsFunnelDashboard.kpiB,
    requiredHeaders: <String>['название', 'дата_с', 'описание'],
    columns: outdoorColumns,
  );

  static const List<GoogleSheetsInputColumn> outdoorColumns = <GoogleSheetsInputColumn>[
    GoogleSheetsInputColumn(
      header: 'название',
      aliases: <String>['title'],
      widthPx: 280,
      missingLabel: 'нет названия',
      note: 'Название. Пустую строку бот пропускает.',
    ),
    GoogleSheetsInputColumn(
      header: 'дата_с',
      aliases: <String>['date_from', 'дата_начала'],
      widthPx: 120,
      kind: GoogleSheetsInputColumnKind.date,
      missingLabel: 'нет даты_с',
      note: 'Дата начала. Выбери в календаре.',
    ),
    GoogleSheetsInputColumn(
      header: 'дата_по',
      aliases: <String>['date_to', 'дата_окончания'],
      widthPx: 120,
      kind: GoogleSheetsInputColumnKind.date,
      emptyHint: 'дата_по пусто = один день',
      note: 'Дата окончания. Пусто = один день. Не подставляй дату_с сами.',
    ),
    GoogleSheetsInputColumn(
      header: 'описание',
      aliases: <String>['description'],
      widthPx: 420,
      wrap: true,
      missingLabel: 'нет описания',
      note: 'Описание в карточке бота. Обязательно, если есть название.',
    ),
    GoogleSheetsInputColumn(
      header: 'место',
      aliases: <String>['location', 'where', 'place', 'где'],
      widthPx: 200,
      wrap: true,
      note: 'Место / регион. Необязательно.',
    ),
    GoogleSheetsInputColumn(
      header: 'цена',
      aliases: <String>['price'],
      widthPx: 80,
      kind: GoogleSheetsInputColumnKind.number,
      note: 'Цена в рублях, число.',
    ),
    GoogleSheetsInputColumn(
      header: 'предоплата',
      aliases: <String>[
        'prepay_percent',
        'prepayment_percent',
        'prepaid_percent',
        'prepay',
        'процент_предоплаты',
      ],
      widthPx: 120,
      kind: GoogleSheetsInputColumnKind.percent,
      emptyHint: 'предоплата 50% по умолчанию',
      note: 'Предоплата 1–100. Пусто = 50%. Не подставляй 50 в пустую ячейку.',
    ),
    GoogleSheetsInputColumn(
      header: 'лимит',
      aliases: <String>[
        'limit',
        'participants_limit',
        'participant_limit',
        'participants',
      ],
      widthPx: 80,
      kind: GoogleSheetsInputColumnKind.number,
      note: 'Лимит мест, число.',
    ),
    GoogleSheetsInputColumn(
      header: 'экипировка',
      aliases: <String>['equipment', 'gear', 'kit'],
      widthPx: 280,
      wrap: true,
      note: 'Экипировка. Необязательно.',
    ),
    GoogleSheetsInputColumn(
      header: 'план',
      aliases: <String>['itinerary', 'schedule', 'timeline', 'program', 'расписание', 'тайминг'],
      widthPx: 280,
      wrap: true,
      note: 'Расписание / план дня. Необязательно.',
    ),
    _statusColumn,
  ];

  static const GoogleSheetsInputSheetSpec coaches = GoogleSheetsInputSheetSpec(
    gid: 195037978,
    title: coachesTitle,
    tabColor: GoogleSheetsFunnelDashboard.kpiC,
    requiredHeaders: <String>['имя', 'username', 'описание'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'имя',
        aliases: <String>['name', 'trainer_name', 'coach', 'fio'],
        widthPx: 200,
        missingLabel: 'нет имени',
        note: 'Имя. Строка без имени / username / описания пропускается.',
      ),
      GoogleSheetsInputColumn(
        header: 'username',
        aliases: <String>['link', 'telegram', 'tg', 'ат', '@', 'ссылка'],
        widthPx: 180,
        missingLabel: 'нет username',
        note: '@username или URL. Без контакта бот строку пропускает.',
      ),
      GoogleSheetsInputColumn(
        header: 'роль',
        aliases: <String>['role', 'specialization', 'direction', 'направление'],
        widthPx: 220,
        wrap: true,
        note: 'Роль в кратком списке. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'описание',
        aliases: <String>['description', 'about', 'bio', 'desc'],
        widthPx: 420,
        wrap: true,
        missingLabel: 'нет описания',
        note: 'Текст в карточке тренера. Обязательно вместе с именем и username.',
      ),
      _statusColumn,
    ],
  );

  static const GoogleSheetsInputSheetSpec team = GoogleSheetsInputSheetSpec(
    gid: 2001400867,
    title: 'Команда DVOR',
    tabColor: headerTab,
    requiredHeaders: <String>['username'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'имя',
        aliases: <String>['name'],
        widthPx: 200,
        note: 'ФИО для людей. Бот эту колонку не читает. Не клади ФИО в username.',
      ),
      GoogleSheetsInputColumn(
        header: 'username',
        aliases: <String>[
          'user_name',
          'telegram',
          'tg',
          'link',
          'ат',
          '@',
          'юзернейм',
          'username_telegram',
        ],
        widthPx: 200,
        missingLabel: 'нет username',
        note: '@name или name. Только ник. Whitelist бесплатной записи.',
      ),
      _statusColumn,
    ],
  );

  static const GoogleSheetsInputSheetSpec promoCodes = GoogleSheetsInputSheetSpec(
    gid: 432112868,
    title: 'Промокоды',
    tabColor: GoogleSheetsFunnelDashboard.kpiB,
    requiredHeaders: <String>['промокод', 'скидка'],
    highlightDuplicateHeader: 'промокод',
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'промокод',
        aliases: <String>['code', 'promocode', 'код'],
        widthPx: 160,
        missingLabel: 'нет промокода',
        note: 'Код. При дубле побеждает последняя строка.',
      ),
      GoogleSheetsInputColumn(
        header: 'скидка',
        aliases: <String>['discount_percent', 'discount', 'percent', 'процент'],
        widthPx: 140,
        kind: GoogleSheetsInputColumnKind.percent,
        missingLabel: 'нет скидки',
        note: 'Скидка 1–100. Знак % можно.',
      ),
      GoogleSheetsInputColumn(
        header: 'категории',
        aliases: <String>[
          'categories',
          'category',
          'категория',
          'тип',
          'тип_мероприятия',
          'мероприятия',
        ],
        widthPx: 220,
        kind: GoogleSheetsInputColumnKind.categories,
        note: 'все / Тренировки / Походы / Трейлы. Можно через запятую. Пусто = все.',
      ),
      GoogleSheetsInputColumn(
        header: 'одноразовый',
        aliases: <String>['single_use', 'singleuse', 'одноразовая', 'одноразовое'],
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: одноразовый промокод.',
      ),
      _statusColumn,
    ],
  );

  static const GoogleSheetsInputColumn _statusColumn = GoogleSheetsInputColumn(
    header: statusHeader,
    widthPx: 280,
    wrap: true,
    kind: GoogleSheetsInputColumnKind.status,
    note: 'Готово или чего не хватает. Формула. Бот колонку не читает.',
  );

  static const List<String> categoryDropdownValues = <String>[
    'все',
    'Тренировки',
    'Походы',
    'Трейлы',
  ];

  static String normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_').replaceAll('ё', 'е');
  }

  static String columnLetter(int column) {
    var n = column + 1;
    final buffer = StringBuffer();
    while (n > 0) {
      n -= 1;
      buffer.writeCharCode(65 + n % 26);
      n ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Locale-aware status formula for data row [row] (1-based A1, header is 1).
  static String statusFormula({
    required GoogleSheetsInputSheetSpec spec,
    required String formulaSep,
    required int targetRows,
    int row = 2,
  }) {
    String cell(String header) {
      final index = spec.indexOfHeader(header);
      if (index == null) {
        throw StateError('${spec.title}: header "$header" is missing from spec.');
      }
      return '${columnLetter(index)}$row';
    }

    final startedParts = <String>[
      for (final column in spec.dataColumns) '${cell(column.header)}<>""',
    ];
    final requiredHeaders = <String>[...spec.requiredHeaders, ...spec.requiredDateHeaders];
    final requiredParts = <String>[
      for (final header in requiredHeaders) '${cell(header)}<>""',
    ];
    final missingParts = <String>[
      for (final header in requiredHeaders)
        'IF(${cell(header)}="";"${spec.columnNamed(header)!.missingLabel}";"")',
    ];
    final hintParts = <String>[
      for (final column in spec.columns)
        if (column.emptyHint != null) 'IF(${cell(column.header)}="";"${column.emptyHint}";"")',
    ];
    final duplicateHeader = spec.highlightDuplicateHeader;
    if (duplicateHeader != null) {
      final letter = columnLetter(spec.indexOfHeader(duplicateHeader)!);
      final dupIf = 'IF(AND(${cell(duplicateHeader)}<>""$formulaSep '
          'COUNTIF(\$$letter\$2:\$$letter\$$targetRows$formulaSep ${cell(duplicateHeader)})>1);'
          '"дубль кода";"")';
      hintParts.add(dupIf);
      missingParts.add(dupIf);
    }

    final started = startedParts.join('$formulaSep ');
    final allRequired = requiredParts.join('$formulaSep ');
    final missingJoin = missingParts.join('$formulaSep ');
    final completeParts = <String>['"готово"', ...hintParts];
    final completeJoin = completeParts.join('$formulaSep ');
    return '=IF(NOT(OR($started));"";IF(AND($allRequired);'
        'TEXTJOIN("; "$formulaSep TRUE$formulaSep $completeJoin);'
        'TEXTJOIN("; "$formulaSep TRUE$formulaSep $missingJoin)))';
  }
}

enum GoogleSheetsInputColumnKind {
  text,
  date,
  time,
  number,
  percent,
  checkbox,
  categories,
  url,
  coach,
  status,
}

final class GoogleSheetsInputColumn {
  const GoogleSheetsInputColumn({
    required this.header,
    required this.widthPx,
    required this.note,
    this.aliases = const <String>[],
    this.kind = GoogleSheetsInputColumnKind.text,
    this.wrap = false,
    this.missingLabel = '',
    this.emptyHint,
  });

  final String header;
  final List<String> aliases;
  final int widthPx;
  final String note;
  final GoogleSheetsInputColumnKind kind;
  final bool wrap;
  final String missingLabel;
  final String? emptyHint;

  bool get isStatus => kind == GoogleSheetsInputColumnKind.status;

  bool get isCheckbox => kind == GoogleSheetsInputColumnKind.checkbox;

  bool matches(String normalizedLiveHeader) {
    if (GoogleSheetsInputUi.normalizeHeader(header) == normalizedLiveHeader) {
      return true;
    }
    for (final alias in aliases) {
      if (GoogleSheetsInputUi.normalizeHeader(alias) == normalizedLiveHeader) {
        return true;
      }
    }
    return false;
  }
}

final class GoogleSheetsInputSheetSpec {
  const GoogleSheetsInputSheetSpec({
    required this.gid,
    required this.title,
    required this.tabColor,
    required this.columns,
    required this.requiredHeaders,
    this.requiredDateHeaders = const <String>[],
    this.highlightDuplicateHeader,
  });

  final int gid;
  final String title;
  final GoogleSheetsRgb tabColor;
  final List<GoogleSheetsInputColumn> columns;
  final List<String> requiredHeaders;
  final List<String> requiredDateHeaders;
  final String? highlightDuplicateHeader;

  Iterable<GoogleSheetsInputColumn> get dataColumns =>
      columns.where((column) => !column.isStatus && !column.isCheckbox);

  Set<String> get checkboxHeaders => columns
      .where((column) => column.isCheckbox)
      .map((column) => GoogleSheetsInputUi.normalizeHeader(column.header))
      .toSet();

  GoogleSheetsInputColumn? columnNamed(String header) {
    final key = GoogleSheetsInputUi.normalizeHeader(header);
    for (final column in columns) {
      if (GoogleSheetsInputUi.normalizeHeader(column.header) == key) {
        return column;
      }
    }
    return null;
  }

  int? indexOfHeader(String header) {
    final key = GoogleSheetsInputUi.normalizeHeader(header);
    for (var i = 0; i < columns.length; i++) {
      if (GoogleSheetsInputUi.normalizeHeader(columns[i].header) == key) {
        return i;
      }
    }
    return null;
  }

  GoogleSheetsInputColumn? matchingColumn(String liveHeader) {
    final normalized = GoogleSheetsInputUi.normalizeHeader(liveHeader);
    if (normalized.isEmpty) {
      return null;
    }
    for (final column in columns) {
      if (column.matches(normalized)) {
        return column;
      }
    }
    return null;
  }
}
