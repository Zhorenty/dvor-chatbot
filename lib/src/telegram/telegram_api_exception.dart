final class TelegramApiException implements Exception {
  const TelegramApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [statusCode=$statusCode]';
    return 'TelegramApiException$code: $message';
  }
}
