part of '../message_templates.dart';

/// Bot copy for Mini App mode (`MINIAPP_ONLY`): the chat is a door into the
/// app plus notifications. Bot UX genre: fact, status, one next step.
extension MessageTemplatesMiniApp on MessageTemplates {
  static const String buttonOpenMiniApp = 'Открыть DVOR';

  /// Inline button that opens the Mini App inside Telegram.
  Map<String, Object?> openMiniAppKeyboard() {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, Object?>>>[
        <Map<String, Object?>>[
          <String, Object?>{
            'text': buttonOpenMiniApp,
            'web_app': <String, Object?>{'url': _miniAppUrl},
          },
        ],
      ],
    };
  }

  String miniAppWelcome({String? firstName}) {
    final name = firstName?.trim();
    final greeting = name == null || name.isEmpty ? 'Привет.' : 'Привет, ${escapeHtml(name)}.';
    return '$greeting Здесь <b>DVOR</b>: тренировки, походы и кэмпы.\n\n'
        'Афиша, запись, оплата и твои записи — в приложении. '
        'Открой его кнопкой ниже или DVOR слева от поля ввода.';
  }

  /// Reply to any other text: the old menu buttons and commands moved.
  String miniAppMovedHint() {
    return 'Всё теперь в приложении <b>DVOR</b>: афиша, запись, оплата и вершинки.\n\n'
        'Кнопка DVOR — слева от поля ввода.';
  }
}
