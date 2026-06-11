import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

abstract interface class TrainingScheduleRepository {
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5});

  List<TrainingInfo> upcomingYoga({DateTime? now, int limit = 5});

  List<OutdoorActivityInfo> upcomingOutdoorActivities({DateTime? now, int limit = 8});

  Future<bool> refresh({bool force = false});
}
