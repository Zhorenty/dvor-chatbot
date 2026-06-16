final class TrainerInfo {
  const TrainerInfo({
    required this.name,
    required this.link,
    required this.description,
    this.role = '',
  });

  final String name;
  final String link;
  final String description;
  final String role;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TrainerInfo &&
            other.name == name &&
            other.link == link &&
            other.description == description &&
            other.role == role;
  }

  @override
  int get hashCode => Object.hash(name, link, description, role);
}
