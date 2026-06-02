import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';

final class StaticTrainerDirectoryRepository implements TrainerDirectoryRepository {
  const StaticTrainerDirectoryRepository({
    List<TrainerInfo> items = const <TrainerInfo>[],
  }) : _items = items;

  final List<TrainerInfo> _items;

  @override
  List<TrainerInfo> list({int limit = 20}) => _items.take(limit).toList(growable: false);

  @override
  Future<bool> refresh({bool force = false}) async => true;
}
