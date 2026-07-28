Map<String, Object?> replyKeyboard(List<List<Map<String, String>>> rows) {
  return <String, Object?>{
    'keyboard': rows,
    'resize_keyboard': true,
    'one_time_keyboard': false,
  };
}
