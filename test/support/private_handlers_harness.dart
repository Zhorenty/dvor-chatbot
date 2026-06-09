import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
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
    Set<int> adminUserIds = const <int>{},
    int? adminChatId,
    int? targetChatId,
    DateTime Function()? nowProvider,
    MessageTemplates templates = const MessageTemplates(),
    FakeBookingRepository? bookingRepository,
    FakeOnboardingRepository? onboardingRepository,
  })  : sender = FakeSender(),
        scheduleRepository = FakeScheduleRepository(
          trainings,
          outdoorItems: outdoorActivities,
        ),
        booking = bookingRepository ?? FakeBookingRepository(),
        onboarding = onboardingRepository ?? FakeOnboardingRepository(),
        trainerDirectoryRepository = FakeTrainerDirectoryRepository(trainers),
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider {
    handlers = PrivateHandlers(
      sender: sender,
      scheduleRepository: scheduleRepository,
      bookingRepository: booking,
      onboardingRepository: onboarding,
      trainerDirectoryRepository: trainerDirectoryRepository,
      templates: _templates,
      adminUserIds: _adminUserIds,
      adminChatId: _adminChatId,
      targetChatId: _targetChatId,
      nowProvider: _nowProvider,
    );
  }

  final FakeSender sender;
  final FakeScheduleRepository scheduleRepository;
  final FakeBookingRepository booking;
  final FakeOnboardingRepository onboarding;
  final TrainerDirectoryRepository trainerDirectoryRepository;
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
