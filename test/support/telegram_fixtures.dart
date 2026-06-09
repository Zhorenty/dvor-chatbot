Map<String, dynamic> privateMessageUpdate({
  required int chatId,
  required int userId,
  required String text,
  String? username,
}) {
  return <String, dynamic>{
    'update_id': DateTime.now().microsecondsSinceEpoch,
    'message': <String, dynamic>{
      'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
      'from': <String, dynamic>{
        'id': userId,
        if (username != null) 'username': username,
      },
      'text': text,
    },
  };
}

Map<String, dynamic> privateCallbackUpdate({
  required String callbackId,
  required int chatId,
  required int userId,
  required String data,
  String? username,
}) {
  return <String, dynamic>{
    'update_id': DateTime.now().microsecondsSinceEpoch,
    'callback_query': <String, dynamic>{
      'id': callbackId,
      'from': <String, dynamic>{
        'id': userId,
        if (username != null) 'username': username,
      },
      'message': <String, dynamic>{
        'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
      },
      'data': data,
    },
  };
}
