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
}) {
  final normalized = normalizeTelegramUsername(username);
  if (normalized == null) {
    return false;
  }
  for (final trainer in trainers) {
    if (telegramUsernameFromLink(trainer.link) == normalized) {
      return true;
    }
  }
  return false;
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
