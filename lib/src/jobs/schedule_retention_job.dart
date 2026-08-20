import 'package:dvor_chatbot/src/application/schedule_catalog_service.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:l/l.dart';

final class ScheduleRetentionJob {
  const ScheduleRetentionJob({
    required ScheduleCatalogService catalogService,
    required TrainingScheduleRepository scheduleRepository,
  })  : _catalogService = catalogService,
        _scheduleRepository = scheduleRepository;

  final ScheduleCatalogService _catalogService;
  final TrainingScheduleRepository _scheduleRepository;

  Future<void> run() async {
    if (!_catalogService.canEdit) {
      return;
    }
    try {
      final result = await _catalogService.purgeExpired();
      l.i(
        'Schedule retention completed. '
        'trainings=${result.trainingsDeleted} '
        'hikes=${result.hikesDeleted} '
        'trails=${result.trailsDeleted}.',
      );
      if (result.totalDeleted > 0) {
        final refreshOk = await _scheduleRepository.refresh(force: true);
        if (!refreshOk) {
          l.w('Schedule retention wrote the table, but cache refresh failed.');
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Schedule retention failed: $error', stackTrace);
    }
  }
}
