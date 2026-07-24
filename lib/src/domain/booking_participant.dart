enum BookingParticipantType {
  self,
  telegram,
  guest;

  String get dbValue => switch (this) {
        BookingParticipantType.self => 'self',
        BookingParticipantType.telegram => 'telegram',
        BookingParticipantType.guest => 'guest',
      };

  static BookingParticipantType fromDbValue(String? value) {
    return switch (value) {
      'telegram' => BookingParticipantType.telegram,
      'guest' => BookingParticipantType.guest,
      _ => BookingParticipantType.self,
    };
  }
}

/// Draft participant for the "book a friend" party builder / group create API.
final class BookingParticipantDraft {
  const BookingParticipantDraft._({
    required this.type,
    this.username,
    this.name,
  });

  const BookingParticipantDraft.self() : this._(type: BookingParticipantType.self);

  const BookingParticipantDraft.telegram({required String username})
      : this._(type: BookingParticipantType.telegram, username: username);

  const BookingParticipantDraft.guest({required String name})
      : this._(type: BookingParticipantType.guest, name: name);

  final BookingParticipantType type;
  final String? username;
  final String? name;

  String get displayLabel {
    return switch (type) {
      BookingParticipantType.self => 'Себя',
      BookingParticipantType.telegram => '@${_stripAt(username ?? '')}',
      BookingParticipantType.guest => name?.trim().isNotEmpty == true ? name!.trim() : 'Гость',
    };
  }

  static String _stripAt(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }
}
