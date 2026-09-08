import 'package:dvor_chatbot/src/messages/html_escaper.dart';

/// Helpers for Telegram rich HTML (`InputRichMessage.html`) and classic HTML fallback.
final class RichHtml {
  const RichHtml._();

  static String heading(String text, {int level = 2}) {
    final tag = 'h${level.clamp(2, 3)}';
    return '<$tag>${escapeHtml(text)}</$tag>';
  }

  static String paragraph(String text, {bool alreadyEscaped = false}) {
    final body = alreadyEscaped ? text : escapeHtml(text);
    return '<p>$body</p>';
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
      final value = alreadyEscaped ? row.$2 : escapeHtml(row.$2);
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
    final bodyHtml = alreadyEscaped ? body : escapeHtml(body);
    return '<details><summary>$summaryHtml</summary>$bodyHtml</details>';
  }

  static String screen({
    required String title,
    String? lead,
    List<String> paragraphs = const <String>[],
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
