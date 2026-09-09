import 'package:dvor_chatbot/src/messages/html_escaper.dart';

/// Helpers for Telegram rich HTML (`InputRichMessage.html`) and classic HTML fallback.
final class RichHtml {
  const RichHtml._();

  static String heading(String text, {int level = 2}) {
    final tag = 'h${level.clamp(2, 3)}';
    return '<$tag>${escapeHtml(text)}</$tag>';
  }

  static String paragraph(String text, {bool alreadyEscaped = false}) {
    if (alreadyEscaped) {
      return '<p>$text</p>';
    }
    return formatted(text);
  }

  static String anchor(String label, String url) {
    return '<a href="${escapeHtml(url)}">${escapeHtml(label)}</a>';
  }

  static String mapsUrl({required String location, String? locationUrl}) {
    final explicit = locationUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return 'https://yandex.ru/maps/?text=${Uri.encodeComponent(location)}';
  }

  static String locationHtml({
    required String location,
    String? locationUrl,
    bool link = true,
  }) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (!link) {
      return escapeHtml(trimmed);
    }
    return anchor(trimmed, mapsUrl(location: trimmed, locationUrl: locationUrl));
  }

  static String facts(List<String> lines, {bool alreadyEscaped = false}) {
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      buffer.write(paragraph(line, alreadyEscaped: alreadyEscaped));
    }
    return buffer.toString();
  }

  /// Visual card for schedule/booking lists. Links stay in `<p>`, not `<td>`.
  static String card({
    required String title,
    int? index,
    List<String> lines = const <String>[],
    String extra = '',
    bool alreadyEscaped = true,
  }) {
    final buffer = StringBuffer('<blockquote>');
    final headingText = index == null ? title : '$index. $title';
    buffer.write(heading(headingText, level: 3));
    buffer.write(facts(lines, alreadyEscaped: alreadyEscaped));
    buffer.write(extra);
    buffer.write('</blockquote>');
    return buffer.toString();
  }

  static final RegExp _bulletPrefix = RegExp(
    r'^\s*(?:[•●▪◦‣·]|[-–—*]|[0-9]{1,2}[.)])\s+',
  );

  /// Turns Google Sheets / plain text (newlines, lists, indent) into rich HTML.
  static String formatted(String text) {
    final lines = _plainLines(text);
    if (lines.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    var index = 0;
    while (index < lines.length) {
      if (lines[index].trim().isEmpty) {
        index++;
        continue;
      }
      if (_isBulletLine(lines[index])) {
        final items = <String>[];
        while (index < lines.length && _isBulletLine(lines[index])) {
          final item = _stripBullet(lines[index]);
          if (item.isNotEmpty) {
            items.add(item);
          }
          index++;
        }
        buffer.write(bullets(items));
        continue;
      }
      final paragraphLines = <String>[];
      while (
          index < lines.length && lines[index].trim().isNotEmpty && !_isBulletLine(lines[index])) {
        paragraphLines.add(lines[index]);
        index++;
      }
      buffer.write('<p>${paragraphLines.map(_indentedLineHtml).join('<br>')}</p>');
    }
    return buffer.toString();
  }

  static String formattedDetails({
    required String summary,
    String? text,
    String? empty,
  }) {
    final trimmed = text?.trim();
    final body = trimmed == null || trimmed.isEmpty
        ? (empty == null ? '' : paragraph(empty))
        : formatted(text!);
    if (body.isEmpty) {
      return '';
    }
    return details(
      summary: summary,
      body: body,
      alreadyEscaped: true,
    );
  }

  static List<String> _plainLines(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final raw = normalized.split('\n').map((line) {
      return line.replaceAll('\t', '  ').replaceAll(RegExp(r' +$'), '');
    }).toList();
    while (raw.isNotEmpty && raw.first.trim().isEmpty) {
      raw.removeAt(0);
    }
    while (raw.isNotEmpty && raw.last.trim().isEmpty) {
      raw.removeLast();
    }
    final lines = <String>[];
    var emptyRun = 0;
    for (final line in raw) {
      if (line.trim().isEmpty) {
        emptyRun++;
        if (emptyRun == 1 && lines.isNotEmpty) {
          lines.add('');
        }
        continue;
      }
      emptyRun = 0;
      lines.add(line);
    }
    return lines;
  }

  static bool _isBulletLine(String line) => _bulletPrefix.hasMatch(line);

  static String _stripBullet(String line) {
    return line.replaceFirst(_bulletPrefix, '').trim();
  }

  static String _indentedLineHtml(String line) {
    final indent = RegExp(r'^ *').firstMatch(line)?.group(0)?.length ?? 0;
    final escaped = escapeHtml(line.trim());
    if (indent <= 0) {
      return escaped;
    }
    return '${'&nbsp;' * indent.clamp(1, 16)}$escaped';
  }

  static String _tableCellHtml(String value) {
    final lines = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.length == 1) {
      return escapeHtml(value);
    }
    return lines.map(_indentedLineHtml).join('<br>');
  }

  static String bullets(List<String> items, {bool alreadyEscaped = false}) {
    if (items.isEmpty) {
      return '';
    }
    final lis = items.map((item) {
      final body = alreadyEscaped ? item : escapeHtml(item);
      return '<li>$body</li>';
    }).join();
    return '<ul>$lis</ul>';
  }

  static String table(List<(String, String)> rows, {bool alreadyEscaped = false}) {
    if (rows.isEmpty) {
      return '';
    }
    final cells = rows.map((row) {
      final key = alreadyEscaped ? row.$1 : escapeHtml(row.$1);
      final value = alreadyEscaped ? row.$2 : _tableCellHtml(row.$2);
      return '<tr><th>$key</th><td>$value</td></tr>';
    }).join();
    return '<table>$cells</table>';
  }

  static String details({
    required String summary,
    required String body,
    bool alreadyEscaped = false,
  }) {
    final summaryHtml = alreadyEscaped ? summary : escapeHtml(summary);
    final bodyHtml = alreadyEscaped ? body : formatted(body);
    return '<details><summary>$summaryHtml</summary>$bodyHtml</details>';
  }

  static String screen({
    required String title,
    String? lead,
    List<String> paragraphs = const <String>[],
    List<String>? facts,
    List<String>? bullets,
    List<(String, String)>? rows,
    String? detailsSummary,
    String? detailsBody,
    String? footer,
    bool alreadyEscaped = false,
  }) {
    final buffer = StringBuffer(heading(title));
    if (lead != null && lead.trim().isNotEmpty) {
      buffer.write(paragraph(lead, alreadyEscaped: alreadyEscaped));
    }
    for (final paragraphText in paragraphs) {
      if (paragraphText.trim().isEmpty) {
        continue;
      }
      buffer.write(paragraph(paragraphText, alreadyEscaped: alreadyEscaped));
    }
    final factLines = facts;
    if (factLines != null && factLines.isNotEmpty) {
      buffer.write(RichHtml.facts(factLines, alreadyEscaped: alreadyEscaped));
    }
    final list = bullets;
    if (list != null && list.isNotEmpty) {
      buffer.write(RichHtml.bullets(list, alreadyEscaped: alreadyEscaped));
    }
    final tableRows = rows;
    if (tableRows != null && tableRows.isNotEmpty) {
      buffer.write(table(tableRows, alreadyEscaped: alreadyEscaped));
    }
    if (detailsSummary != null && detailsBody != null && detailsBody.trim().isNotEmpty) {
      buffer.write(
        details(
          summary: detailsSummary,
          body: detailsBody,
          alreadyEscaped: alreadyEscaped,
        ),
      );
    }
    if (footer != null && footer.trim().isNotEmpty) {
      buffer.write('<footer>${alreadyEscaped ? footer : escapeHtml(footer)}</footer>');
    }
    return buffer.toString();
  }

  static String detailsBlocks(
    List<(String, String)> blocks, {
    bool alreadyEscaped = false,
  }) {
    if (blocks.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block.$2.trim().isEmpty) {
        continue;
      }
      buffer.write(
        details(
          summary: block.$1,
          body: block.$2,
          alreadyEscaped: alreadyEscaped,
        ),
      );
    }
    return buffer.toString();
  }

  /// Classic `parse_mode=HTML` subset: `<b>`, `<code>`, `<a>`, line breaks.
  static String fallback(String richHtml) {
    var text = richHtml;
    text = text.replaceAllMapped(
      RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false, dotAll: true),
      (match) => '<b>${match[1]}</b>\n',
    );
    text = text.replaceAll(RegExp(r'</p>\s*<p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (match) => '• ${match[1]}\n',
    );
    text = text.replaceAll(RegExp(r'</?[uo]l[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n———\n');
    text = text.replaceAllMapped(
      RegExp(
        r'<details[^>]*>\s*<summary>(.*?)</summary>(.*?)</details>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '<b>${match[1]}</b>\n${match[2]}\n',
    );
    text = text.replaceAll(RegExp(r'</?blockquote[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</?footer[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'<tg-button-row[^>]*>.*?</tg-button-row>', caseSensitive: false, dotAll: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<tg-button[^>]*>.*?</tg-button>', caseSensitive: false, dotAll: true),
      '',
    );
    text = text.replaceAll(RegExp(r'</tr>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</t[dh]>', caseSensitive: false), ' · ');
    text = text.replaceAll(RegExp(r'</?t(?:able|head|body|r|h|d)[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
