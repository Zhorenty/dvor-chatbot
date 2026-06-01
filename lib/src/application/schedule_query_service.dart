import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';

final class ScheduleQueryService {
  const ScheduleQueryService({
    required ActivityCatalogService catalogService,
    required MessageTemplates templates,
  })  : _catalogService = catalogService,
        _templates = templates;

  final ActivityCatalogService _catalogService;
  final MessageTemplates _templates;

  String scheduleText(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => _templates.trainings(_catalogService.bookableItems(category)),
      ActivityCategory.hikes => _templates.hikes(_catalogService.outdoorItems(category)),
      ActivityCategory.trails => _templates.trails(_catalogService.outdoorItems(category)),
    };
  }
}
