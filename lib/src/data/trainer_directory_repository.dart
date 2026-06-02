import 'package:dvor_chatbot/src/domain/trainer_info.dart';

abstract interface class TrainerDirectoryRepository {
  List<TrainerInfo> list({int limit = 20});

  Future<bool> refresh({bool force = false});
}

final class NoopTrainerDirectoryRepository implements TrainerDirectoryRepository {
  const NoopTrainerDirectoryRepository();

  @override
  List<TrainerInfo> list({int limit = 20}) => const <TrainerInfo>[];

  @override
  Future<bool> refresh({bool force = false}) async => true;
}
