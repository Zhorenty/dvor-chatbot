import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';

/// Manual input-sheet look: same palette as [GoogleSheetsFunnelDashboard], but
/// these tabs stay as CSV forms. The bot must never rewrite them on a timer.
abstract final class GoogleSheetsInputUi {
  static const String spreadsheetId = '1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q';
  static const String legendTitle = 'КАК ЗАПОЛНЯТЬ';
  static const String funnelTitle = 'FUNNEL';
  static const int extraRows = 40;

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
    requiredHeaders: <String>['title', 'location'],
    requiredDateHeaders: <String>['date', 'time'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'title',
        widthPx: 280,
        note: 'Название. Пример: BOXING DVOR. Пустую строку бот пропускает.',
      ),
      GoogleSheetsInputColumn(
        header: 'date',
        widthPx: 110,
        kind: GoogleSheetsInputColumnKind.date,
        note: 'Дата. Выбери в календаре. Формат 19.08.2026.',
      ),
      GoogleSheetsInputColumn(
        header: 'time',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.time,
        note: 'Время начала. Пример: 19:30.',
      ),
      GoogleSheetsInputColumn(
        header: 'location',
        widthPx: 240,
        wrap: true,
        note: 'Место. Пример: Стадион Кубань.',
      ),
      GoogleSheetsInputColumn(
        header: 'location_url',
        widthPx: 220,
        kind: GoogleSheetsInputColumnKind.url,
        note: 'Ссылка на карту. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'include_trainers',
        widthPx: 130,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: считать тренеров в лимите мест. CSV: TRUE/FALSE.',
      ),
      GoogleSheetsInputColumn(
        header: 'promo_restricted',
        widthPx: 130,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: промокод на эту тренировку не действует.',
      ),
      GoogleSheetsInputColumn(
        header: 'coach',
        widthPx: 170,
        note: 'Имя тренера. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'price',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Цена в рублях, число. Можно 350 или 350₽.',
      ),
      GoogleSheetsInputColumn(
        header: 'limit',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Лимит мест, число. Алиас participants_limit.',
      ),
      GoogleSheetsInputColumn(
        header: 'notes',
        widthPx: 360,
        wrap: true,
        note: 'Текст в карточке бота. Необязательно.',
      ),
    ],
  );

  static const GoogleSheetsInputSheetSpec hikes = GoogleSheetsInputSheetSpec(
    gid: 294119056,
    title: 'Походы',
    tabColor: GoogleSheetsFunnelDashboard.section,
    requiredHeaders: <String>['title', 'date_from', 'description'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'title',
        widthPx: 280,
        note: 'Название похода. Пустую строку бот пропускает.',
      ),
      GoogleSheetsInputColumn(
        header: 'date_from',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.date,
        note: 'Дата начала. Выбери в календаре.',
      ),
      GoogleSheetsInputColumn(
        header: 'date_to',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.date,
        note: 'Дата окончания. Пусто = один день.',
      ),
      GoogleSheetsInputColumn(
        header: 'location',
        widthPx: 200,
        wrap: true,
        note: 'Место / регион. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'price',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Цена в рублях, число.',
      ),
      GoogleSheetsInputColumn(
        header: 'prepay_percent',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.percent,
        note: 'Предоплата 1–100. Пусто = 50%.',
      ),
      GoogleSheetsInputColumn(
        header: 'limit',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Лимит мест, число.',
      ),
      GoogleSheetsInputColumn(
        header: 'equipment',
        widthPx: 280,
        wrap: true,
        note: 'Экипировка. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'itinerary',
        widthPx: 280,
        wrap: true,
        note: 'Расписание / план дня. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'description',
        widthPx: 420,
        wrap: true,
        note: 'Описание в карточке бота. Обязательно, если есть название.',
      ),
    ],
  );

  static const GoogleSheetsInputSheetSpec trails = GoogleSheetsInputSheetSpec(
    gid: 1220729038,
    title: 'Трейлы',
    tabColor: GoogleSheetsFunnelDashboard.kpiB,
    requiredHeaders: <String>['title', 'date_from', 'description'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'title',
        widthPx: 240,
        note: 'Название трейла. Пустую строку бот пропускает.',
      ),
      GoogleSheetsInputColumn(
        header: 'date_from',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.date,
        note: 'Дата начала. Выбери в календаре.',
      ),
      GoogleSheetsInputColumn(
        header: 'date_to',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.date,
        note: 'Дата окончания. Пусто = один день.',
      ),
      GoogleSheetsInputColumn(
        header: 'location',
        widthPx: 180,
        wrap: true,
        note: 'Место старта. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'description',
        widthPx: 420,
        wrap: true,
        note: 'Описание в карточке бота. Обязательно, если есть название.',
      ),
      GoogleSheetsInputColumn(
        header: 'price',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Цена в рублях, число.',
      ),
      GoogleSheetsInputColumn(
        header: 'limit',
        widthPx: 80,
        kind: GoogleSheetsInputColumnKind.number,
        note: 'Лимит мест, число.',
      ),
    ],
  );

  static const GoogleSheetsInputSheetSpec coaches = GoogleSheetsInputSheetSpec(
    gid: 195037978,
    title: 'Тренерский штаб',
    tabColor: GoogleSheetsFunnelDashboard.kpiC,
    requiredHeaders: <String>['name', 'username', 'description'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'name',
        widthPx: 200,
        note: 'Имя. Строка без имени / контакта / описания пропускается.',
      ),
      GoogleSheetsInputColumn(
        header: 'username',
        widthPx: 180,
        note: 'Контакт: @username или URL. Колонка — алиас link.',
      ),
      GoogleSheetsInputColumn(
        header: 'role',
        widthPx: 220,
        wrap: true,
        note: 'Роль в кратком списке. Необязательно.',
      ),
      GoogleSheetsInputColumn(
        header: 'description',
        widthPx: 420,
        wrap: true,
        note: 'Текст в карточке тренера. Обязательно вместе с именем и контактом.',
      ),
    ],
  );

  static const GoogleSheetsInputSheetSpec team = GoogleSheetsInputSheetSpec(
    gid: 2001400867,
    title: 'Команда DVOR',
    tabColor: headerTab,
    requiredHeaders: <String>['username'],
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'name',
        widthPx: 200,
        note: 'ФИО для людей. Бот эту колонку не читает.',
      ),
      GoogleSheetsInputColumn(
        header: 'username',
        widthPx: 200,
        note: '@name или name. Только ник. Whitelist бесплатной записи.',
      ),
    ],
  );

  static const GoogleSheetsInputSheetSpec promoCodes = GoogleSheetsInputSheetSpec(
    gid: 432112868,
    title: 'Промокоды',
    tabColor: GoogleSheetsFunnelDashboard.kpiB,
    requiredHeaders: <String>['code', 'discount_percent'],
    highlightDuplicateHeader: 'code',
    columns: <GoogleSheetsInputColumn>[
      GoogleSheetsInputColumn(
        header: 'code',
        widthPx: 160,
        note: 'Код. При дубле побеждает последняя строка.',
      ),
      GoogleSheetsInputColumn(
        header: 'discount_percent',
        widthPx: 140,
        kind: GoogleSheetsInputColumnKind.percent,
        note: 'Скидка 1–100. Знак % можно.',
      ),
      GoogleSheetsInputColumn(
        header: 'categories',
        widthPx: 280,
        kind: GoogleSheetsInputColumnKind.categories,
        note: 'Категории через запятую. Пусто / все / all = все категории. '
            'Живые значения: Тренировки, Походы, Трейлы.',
      ),
      GoogleSheetsInputColumn(
        header: 'single_use',
        widthPx: 120,
        kind: GoogleSheetsInputColumnKind.checkbox,
        note: 'Галка: одноразовый промокод.',
      ),
    ],
  );

  static const List<String> categoryDropdownValues = <String>[
    'все',
    'Тренировки',
    'Походы',
    'Трейлы',
    'Тренировки, Походы',
    'Тренировки, Трейлы',
    'Походы, Трейлы',
    'Походы, Тренировки, Трейлы',
    'Тренировки, Походы, Трейлы',
  ];

  static String normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_').replaceAll('ё', 'е');
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
}

final class GoogleSheetsInputColumn {
  const GoogleSheetsInputColumn({
    required this.header,
    required this.widthPx,
    required this.note,
    this.kind = GoogleSheetsInputColumnKind.text,
    this.wrap = false,
  });

  final String header;
  final int widthPx;
  final String note;
  final GoogleSheetsInputColumnKind kind;
  final bool wrap;
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

  Set<String> get checkboxHeaders => columns
      .where((column) => column.kind == GoogleSheetsInputColumnKind.checkbox)
      .map((column) => GoogleSheetsInputUi.normalizeHeader(column.header))
      .toSet();
}
