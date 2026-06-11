import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';

final class ScheduleQueryService {
  const ScheduleQueryService({
    required ActivityCatalogService catalogService,
    required TrainerDirectoryRepository trainerDirectoryRepository,
    required MessageTemplates templates,
  })  : _catalogService = catalogService,
        _trainerDirectoryRepository = trainerDirectoryRepository,
        _templates = templates;

  final ActivityCatalogService _catalogService;
  final TrainerDirectoryRepository _trainerDirectoryRepository;
  final MessageTemplates _templates;

  String scheduleText(ActivityCategory category) {
    final trainers = _trainerDirectoryRepository.list(limit: 100);
    return switch (category) {
      ActivityCategory.trainings =>
        _templates.trainings(_catalogService.bookableItems(category), trainers: trainers),
      ActivityCategory.yoga =>
        _templates.yoga(_catalogService.bookableItems(category), trainers: trainers),
      ActivityCategory.hikes => _templates.hikes(_catalogService.outdoorItems(category)),
      ActivityCategory.trails => _templates.trails(_catalogService.outdoorItems(category)),
    };
  }
}
