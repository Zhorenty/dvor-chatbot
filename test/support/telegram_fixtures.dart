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

Map<String, dynamic> privatePhotoMessageUpdate({
  required int chatId,
  required int userId,
  required int messageId,
  String? username,
  String? caption,
  String? mediaGroupId,
  String fileId = 'photo_file',
}) {
  return <String, dynamic>{
    'update_id': DateTime.now().microsecondsSinceEpoch,
    'message': <String, dynamic>{
      'message_id': messageId,
      'chat': <String, dynamic>{'id': chatId, 'type': 'private'},
      'from': <String, dynamic>{
        'id': userId,
        if (username != null) 'username': username,
      },
      'photo': <Map<String, Object?>>[
        <String, Object?>{'file_id': fileId},
      ],
      if (caption != null) 'caption': caption,
      if (mediaGroupId != null) 'media_group_id': mediaGroupId,
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
