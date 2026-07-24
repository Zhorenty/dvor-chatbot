import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

typedef StartCleanup = Future<void> Function(int userId);
typedef EveryFifthNotifier = Future<void> Function({
  required int userId,
  required int chatId,
  required String? username,
});
typedef WelcomePinner = Future<void> Function({
  required int chatId,
  required int messageId,
});
typedef NowProvider = DateTime Function();

final class PrivateStaticCommands {
  const PrivateStaticCommands();

  Future<bool> handle({
    required String? text,
    required int chatId,
    required int? userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required Map<int, PrivateFlowState> flowByUserId,
    required TrainerDirectoryRepository trainerDirectoryRepository,
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required bool canViewParticipantsList,
    required StartCleanup onStartCleanup,
    required EveryFifthNotifier onEveryFifthUnlocked,
    required WelcomePinner onPinWelcomeMessage,
    required NowProvider nowProvider,
    String? username,
  }) async {
    if (text == null) {
      return false;
    }
    if (text.startsWith('/start')) {
      final startPayload = _parseStartPayload(text);
      var starterBonusAvailable = false;
      if (userId != null) {
        final referralInviterId = _parseReferralInviterId(text);
        if (referralInviterId != null) {
          await onboardingRepository.registerReferralAttribution(
            inviteeUserId: userId,
            inviterUserId: referralInviterId,
            attributedAt: nowProvider(),
          );
        }
        flowByUserId.remove(userId);
        await onStartCleanup(userId);
        starterBonusAvailable = await onboardingRepository.hasStarterBonusAvailable(userId);
        await onEveryFifthUnlocked(userId: userId, chatId: chatId, username: username);
      }
      final welcomeMessageId = await sender.sendMessage(
        chatId,
        templates.privateWelcome(),
        replyMarkup: templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
        parseMode: 'HTML',
      );
      await onPinWelcomeMessage(chatId: chatId, messageId: welcomeMessageId);
      if (starterBonusAvailable) {
        await sender.sendMessage(
          chatId,
          templates.starterBonusOnboardingOffer(),
          replyMarkup: templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            canViewParticipantsList: canViewParticipantsList,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
      }
      if (startPayload == 'book' && userId != null) {
        flowByUserId[userId] = const PrivateFlowState(
          step: PrivateFlowStep.selectingBookingCategory,
          availableTrainings: <TrainingInfo>[],
        );
        await sender.sendMessage(
          chatId,
          templates.chooseBookingCategory(),
          replyMarkup: templates.categorySelectionKeyboard(),
        );
      }
      return true;
    }

    if (text.startsWith('/trainings') || text == MessageTemplates.buttonTrainings) {
      if (userId == null) {
        return false;
      }
      flowByUserId[userId] = const PrivateFlowState(
        step: PrivateFlowStep.selectingScheduleCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await sender.sendMessage(
        chatId,
        templates.chooseScheduleCategory(),
        replyMarkup: templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text.startsWith('/coaches') || text == MessageTemplates.buttonCoachingStaff) {
      final refreshOk = await trainerDirectoryRepository.refresh();
      if (!refreshOk) {
        l.w('Trainer directory refresh failed. Using cached trainers list.');
      }
      final trainers = trainerDirectoryRepository.list(limit: 30);
      if (userId != null) {
        flowByUserId[userId] = PrivateFlowState(
          step: PrivateFlowStep.viewingCoachingStaff,
          availableTrainings: const <TrainingInfo>[],
          availableTrainers: trainers,
        );
      }
      await sender.sendMessage(
        chatId,
        templates.coachingStaff(trainers),
        replyMarkup: templates.coachingStaffActionsKeyboard(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return true;
    }

    if (text == MessageTemplates.buttonDvorXFrank) {
      if (userId != null) {
        flowByUserId.remove(userId);
      }
      await sender.sendMessage(
        chatId,
        templates.dvorXFrankPromo(),
        replyMarkup: templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
        parseMode: 'HTML',
      );
      return true;
    }

    if (text == MessageTemplates.buttonHelp) {
      if (userId != null) {
        flowByUserId.remove(userId);
      }
      await sender.sendMessage(
        chatId,
        templates.privateHelp(),
        replyMarkup: templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }

    if (text == MessageTemplates.buttonMainMenu || text == MessageTemplates.buttonAdminMenu) {
      if (userId == null) {
        return false;
      }
      flowByUserId.remove(userId);
      await sender.sendMessage(
        chatId,
        text == MessageTemplates.buttonAdminMenu ? 'Админ-меню 👇' : 'Главное меню 👇',
        replyMarkup: templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }

    return false;
  }

  String? _parseStartPayload(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return parts[1].trim().toLowerCase();
  }

  int? _parseReferralInviterId(String text) {
    final payload = _parseStartPayload(text);
    if (payload == null || !payload.startsWith('ref_')) {
      return null;
    }
    return int.tryParse(payload.substring(4));
  }
}
