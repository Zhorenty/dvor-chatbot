import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:l/l.dart';

final class ScheduleSyncJob {
  const ScheduleSyncJob({
    required TrainingScheduleRepository scheduleRepository,
  }) : _scheduleRepository = scheduleRepository;

  final TrainingScheduleRepository _scheduleRepository;

  Future<void> run() async {
    final refreshOk = await _scheduleRepository.refresh();
    if (!refreshOk) {
      l.w('Background schedule refresh failed.');
    }
  }
}
