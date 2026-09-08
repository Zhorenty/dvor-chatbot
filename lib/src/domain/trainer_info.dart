enum StaffKind { coach, team }

abstract final class StaffKindLabels {
  static const String coach = 'Тренер';
  static const String team = 'Команда DVOR';

  static StaffKind parse(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.contains('команда') ||
        normalized == 'team' ||
        normalized == 'dvor team' ||
        normalized == 'dvor_team') {
      return StaffKind.team;
    }
    return StaffKind.coach;
  }

  static bool isKnown(String? raw) {
    final normalized = _normalize(raw);
    return normalized == 'тренер' ||
        normalized == 'coach' ||
        normalized == 'trainer' ||
        normalized.contains('команда') ||
        normalized == 'team' ||
        normalized == 'dvor team' ||
        normalized == 'dvor_team';
  }

  static String _normalize(String? raw) {
    return (raw ?? '').trim().toLowerCase().replaceAll('ё', 'е');
  }
}

final class TrainerInfo {
  const TrainerInfo({
    required this.name,
    required this.link,
    required this.description,
    this.role = '',
    this.kind = StaffKind.coach,
  });

  final String name;
  final String link;
  final String description;
  final String role;
  final StaffKind kind;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TrainerInfo &&
            other.name == name &&
            other.link == link &&
            other.description == description &&
            other.role == role &&
            other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(name, link, description, role, kind);
}
