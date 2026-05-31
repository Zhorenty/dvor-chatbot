import 'package:dvor_chatbot/src/domain/training_info.dart';

abstract interface class TrainingScheduleRepository {
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5});

  Future<bool> refresh({bool force = false});
}
