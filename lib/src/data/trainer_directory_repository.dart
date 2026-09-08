import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';

abstract interface class TrainerDirectoryRepository {
  List<TrainerInfo> list({int limit = 20});

  bool containsUsername(String? username);

  Future<bool> refresh({bool force = false});
}

bool trainerDirectoryContainsUsername({
  required Iterable<TrainerInfo> trainers,
  required String? username,
  bool coachesOnly = true,
}) {
  final normalized = normalizeTelegramUsername(username);
  if (normalized == null) {
    return false;
  }
  for (final trainer in trainers) {
    if (coachesOnly && trainer.kind != StaffKind.coach) {
      continue;
    }
    if (telegramUsernameFromLink(trainer.link) == normalized) {
      return true;
    }
  }
  return false;
}

List<TrainerInfo> staffDirectoryList({
  required Iterable<TrainerInfo> people,
  int limit = 20,
}) {
  final coaches = people.where((item) => item.kind == StaffKind.coach);
  final team = people.where((item) => item.kind == StaffKind.team);
  return <TrainerInfo>[...coaches, ...team].take(limit).toList(growable: false);
}

final class NoopTrainerDirectoryRepository implements TrainerDirectoryRepository {
  const NoopTrainerDirectoryRepository();

  @override
  List<TrainerInfo> list({int limit = 20}) => const <TrainerInfo>[];

  @override
  bool containsUsername(String? username) => false;

  @override
  Future<bool> refresh({bool force = false}) async => true;
}
