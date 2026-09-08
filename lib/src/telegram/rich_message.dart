import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/rich_html.dart';

/// Style for in-message [RichMessageButton] (Bot API 10.3).
enum RichButtonStyle {
  primary,
  success,
  danger,
  link,
}

/// In-message button for [InputRichMessage.html] (`<tg-button>`).
final class RichMessageButton {
  const RichMessageButton._({
    required this.text,
    this.style,
    this.callbackData,
    this.url,
    this.copyText,
  });

  const RichMessageButton.callback({
    required String text,
    required String callbackData,
    RichButtonStyle? style,
  }) : this._(text: text, style: style, callbackData: callbackData);

  const RichMessageButton.url({
    required String text,
    required String url,
    RichButtonStyle style = RichButtonStyle.link,
  }) : this._(text: text, style: style, url: url);

  const RichMessageButton.copy({
    required String text,
    required String copyText,
    RichButtonStyle style = RichButtonStyle.link,
  }) : this._(text: text, style: style, copyText: copyText);

  final String text;
  final RichButtonStyle? style;
  final String? callbackData;
  final String? url;
  final String? copyText;

  String toHtml() {
    final attributes = <String>[];
    final styleName = style?.name;
    if (styleName != null) {
      attributes.add('data-style="${escapeHtml(styleName)}"');
    }
    final callback = callbackData;
    if (callback != null) {
      attributes.add('data-callback-data="${escapeHtml(callback)}"');
    }
    final href = url;
    if (href != null) {
      attributes.add('data-url="${escapeHtml(href)}"');
    }
    final copy = copyText;
    if (copy != null) {
      attributes.add('data-copy-text="${escapeHtml(copy)}"');
    }
    final attr = attributes.isEmpty ? '' : ' ${attributes.join(' ')}';
    return '<tg-button$attr>${escapeHtml(text)}</tg-button>';
  }

  Map<String, Object?> toApiJson() {
    return <String, Object?>{
      'text': text,
      if (style != null) 'style': style!.name,
      if (callbackData != null) 'callback_data': callbackData,
      if (url != null) 'url': url,
      if (copyText != null) 'copy_text': <String, Object?>{'text': copyText},
    };
  }

  Map<String, Object?> toInlineKeyboardButton() {
    return <String, Object?>{
      'text': text,
      if (callbackData != null) 'callback_data': callbackData,
      if (url != null) 'url': url,
      if (copyText != null) 'copy_text': <String, Object?>{'text': copyText},
    };
  }
}

/// Bot-owned rich payload: Telegram `InputRichMessage.html` plus a classic HTML fallback.
final class InputRichMessage {
  InputRichMessage({
    required this.html,
    String? fallbackHtml,
    this.buttonRows = const <List<RichMessageButton>>[],
  }) : fallbackHtml = fallbackHtml ?? RichHtml.fallback(html);

  final String html;
  final String fallbackHtml;
  final List<List<RichMessageButton>> buttonRows;

  String get htmlWithButtons {
    if (buttonRows.isEmpty) {
      return html;
    }
    final buffer = StringBuffer(html);
    for (final row in buttonRows) {
      if (row.isEmpty) {
        continue;
      }
      buffer
        ..write('\n<tg-button-row>')
        ..write(row.map((button) => button.toHtml()).join())
        ..write('</tg-button-row>');
    }
    return buffer.toString();
  }

  Map<String, Object?> toApiJson() {
    return <String, Object?>{
      'html': htmlWithButtons,
    };
  }

  Map<String, Object?>? fallbackInlineKeyboard() {
    if (buttonRows.isEmpty) {
      return null;
    }
    final rows = <List<Map<String, Object?>>>[];
    for (final row in buttonRows) {
      if (row.isEmpty) {
        continue;
      }
      rows.add(
        row.map((button) => button.toInlineKeyboardButton()).toList(growable: false),
      );
    }
    if (rows.isEmpty) {
      return null;
    }
    return <String, Object?>{'inline_keyboard': rows};
  }
}
