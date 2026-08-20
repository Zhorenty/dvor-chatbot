import 'package:dvor_chatbot/src/application/schedule_catalog_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/dvor_team_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';

import 'fakes.dart';
import 'telegram_fixtures.dart';

final class PrivateHandlersHarness {
  PrivateHandlersHarness({
    List<TrainingInfo> trainings = const <TrainingInfo>[],
    List<OutdoorActivityInfo> outdoorActivities = const <OutdoorActivityInfo>[],
    List<TrainerInfo> trainers = const <TrainerInfo>[],
    DvorTeamRepository? dvorTeamRepository,
    Set<int> adminUserIds = const <int>{},
    int? adminChatId,
    int? targetChatId,
    DateTime Function()? nowProvider,
    MessageTemplates templates = const MessageTemplates(),
    FakeBookingRepository? bookingRepository,
    FakeOnboardingRepository? onboardingRepository,
    SubscriptionRepository subscriptionRepository = const NoopSubscriptionRepository(),
    bool onboardingDripEnabled = false,
    ScheduleCatalogService? scheduleCatalogService,
  })  : sender = FakeSender(),
        scheduleRepository = FakeScheduleRepository(
          trainings,
          outdoorItems: outdoorActivities,
        ),
        booking = bookingRepository ?? FakeBookingRepository(),
        onboarding = onboardingRepository ?? FakeOnboardingRepository(),
        trainerDirectoryRepository = FakeTrainerDirectoryRepository(trainers),
        dvorTeamRepository = dvorTeamRepository ?? const NoopDvorTeamRepository(),
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider {
    handlers = PrivateHandlers(
      sender: sender,
      scheduleRepository: scheduleRepository,
      bookingRepository: booking,
      subscriptionRepository: subscriptionRepository,
      onboardingRepository: onboarding,
      trainerDirectoryRepository: trainerDirectoryRepository,
      dvorTeamRepository: this.dvorTeamRepository,
      templates: _templates,
      adminUserIds: _adminUserIds,
      adminChatId: _adminChatId,
      targetChatId: _targetChatId,
      onboardingDripEnabled: onboardingDripEnabled,
      nowProvider: _nowProvider,
      scheduleCatalogService: scheduleCatalogService,
    );
  }

  final FakeSender sender;
  final FakeScheduleRepository scheduleRepository;
  final FakeBookingRepository booking;
  final FakeOnboardingRepository onboarding;
  final TrainerDirectoryRepository trainerDirectoryRepository;
  final DvorTeamRepository dvorTeamRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final int? _targetChatId;
  final DateTime Function()? _nowProvider;

  late final PrivateHandlers handlers;

  Future<bool> handleText({
    required int chatId,
    required int userId,
    required String text,
    String? username,
  }) {
    return handlers.handle(
      privateMessageUpdate(
        chatId: chatId,
        userId: userId,
        text: text,
        username: username,
      ),
    );
  }

  Future<bool> handleCallback({
    required String callbackId,
    required int chatId,
    required int userId,
    required String data,
    String? username,
  }) {
    return handlers.handle(
      privateCallbackUpdate(
        callbackId: callbackId,
        chatId: chatId,
        userId: userId,
        data: data,
        username: username,
      ),
    );
  }

  List<SentMessage> messagesTo(int chatId) =>
      sender.messages.where((item) => item.chatId == chatId).toList(growable: false);
}
