import 'package:dvor_chatbot/src/messages/rich_html.dart';
import 'package:test/test.dart';

void main() {
  group('RichHtml.formatted', () {
    test('turns blank lines into separate paragraphs', () {
      final html = RichHtml.formatted('Первый абзац\n\nВторой абзац');

      expect(html, contains('<p>Первый абзац</p>'));
      expect(html, contains('<p>Второй абзац</p>'));
      expect(html, isNot(contains('Первый абзац\n')));
    });

    test('keeps single newlines as line breaks', () {
      expect(
        RichHtml.formatted('Дневной маршрут\nс красивыми видами'),
        '<p>Дневной маршрут<br>с красивыми видами</p>',
      );
    });

    test('turns bullet lines into a list', () {
      final html = RichHtml.formatted(
        'Готовы к вызову?\n\n'
        '• реальные подъемы\n'
        '• живописные тропы',
      );

      expect(html, contains('<p>Готовы к вызову?</p>'));
      expect(html, contains('<ul><li>реальные подъемы</li><li>живописные тропы</li></ul>'));
      expect(html, isNot(contains('• реальные подъемы')));
    });

    test('preserves leading indent as nbsp', () {
      expect(
        RichHtml.formatted('  с отступом'),
        '<p>&nbsp;&nbsp;с отступом</p>',
      );
    });

    test('escapes sheets text', () {
      expect(
        RichHtml.formatted('A < B & C'),
        '<p>A &lt; B &amp; C</p>',
      );
    });
  });

  group('RichHtml.fallback', () {
    test('restores paragraphs, breaks and bullets for classic HTML', () {
      final rich = RichHtml.formatted(
        'Первый\n\n'
        'строка\nвторая\n\n'
        '• пункт',
      );

      expect(RichHtml.fallback(rich), 'Первый\n\nстрока\nвторая\n• пункт');
    });
  });

  group('RichHtml.paragraph and details', () {
    test('paragraph keeps sheets line breaks', () {
      expect(
        RichHtml.paragraph('раз\nдва'),
        '<p>раз<br>два</p>',
      );
    });

    test('details body keeps sheets paragraphs', () {
      final html = RichHtml.details(
        summary: 'Описание',
        body: 'Первый\n\nВторой',
      );

      expect(html, contains('<summary>Описание</summary>'));
      expect(html, contains('<p>Первый</p><p>Второй</p>'));
    });
  });

  group('RichHtml.card and locationHtml', () {
    test('puts location links in a paragraph, not a table', () {
      final html = RichHtml.card(
        title: 'CROSSFIT',
        index: 1,
        lines: <String>[
          '🕒 19:30',
          '📍 ${RichHtml.locationHtml(location: 'Стадион Кубань', locationUrl: 'https://maps.example/kuban')}',
        ],
      );

      expect(html, startsWith('<blockquote>'));
      expect(html, contains('<h3>1. CROSSFIT</h3>'));
      expect(
        html,
        contains('<p>📍 <a href="https://maps.example/kuban">Стадион Кубань</a></p>'),
      );
      expect(html, isNot(contains('<table>')));
    });

    test('falls back to yandex search when map url is missing', () {
      expect(
        RichHtml.locationHtml(location: 'Зал DVOR'),
        '<a href="https://yandex.ru/maps/?text=%D0%97%D0%B0%D0%BB%20DVOR">Зал DVOR</a>',
      );
    });
  });
}
