import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';

abstract interface class DvorTeamRepository {
  Future<bool> refresh({bool force = false});

  bool containsUsername(String? username);

  Set<String> usernames();
}

final class NoopDvorTeamRepository implements DvorTeamRepository {
  const NoopDvorTeamRepository();

  @override
  Future<bool> refresh({bool force = false}) async => true;

  @override
  bool containsUsername(String? username) => false;

  @override
  Set<String> usernames() => const <String>{};
}

final class StaticDvorTeamRepository implements DvorTeamRepository {
  const StaticDvorTeamRepository({
    Set<String> usernames = const <String>{},
  }) : _usernames = usernames;

  final Set<String> _usernames;

  @override
  Future<bool> refresh({bool force = false}) async => true;

  @override
  bool containsUsername(String? username) {
    final normalized = normalizeTelegramUsername(username);
    if (normalized == null) {
      return false;
    }
    return _normalizedUsernames.contains(normalized);
  }

  @override
  Set<String> usernames() => Set<String>.unmodifiable(_normalizedUsernames);

  Set<String> get _normalizedUsernames =>
      _usernames.map(normalizeTelegramUsername).whereType<String>().toSet();
}
