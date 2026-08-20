import 'package:dvor_chatbot/src/application/onboarding_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private/private_flow_store.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
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
typedef BookingCategoryOpener = Future<void> Function({
  required int chatId,
  required int userId,
  required bool isAdmin,
  required bool canViewParticipantsList,
  required bool showReturnToAdminMenu,
});

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
    required OnboardingService onboardingService,
    required MessageSender sender,
    required MessageTemplates templates,
    required bool canViewParticipantsList,
    required StartCleanup onStartCleanup,
    required EveryFifthNotifier onEveryFifthUnlocked,
    required WelcomePinner onPinWelcomeMessage,
    required NowProvider nowProvider,
    required BookingCategoryOpener onOpenBookingCategories,
    String? username,
  }) async {
    if (text == null) {
      return false;
    }
    if (text.startsWith('/start')) {
      final startPayload = _parseStartPayload(text);
      var starterBonusAvailable = false;
      var runFunnel = false;
      OnboardingUserState? onboardingState;
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
        onboardingState = await onboardingService.ensureStarted(
          userId,
          startedAt: nowProvider(),
          entryType: referralInviterId != null ? OnboardingEntryType.referral : null,
        );
        runFunnel = await onboardingService.shouldRunFunnel(userId);
        starterBonusAvailable = await onboardingRepository.hasStarterBonusAvailable(userId);
        await onEveryFifthUnlocked(userId: userId, chatId: chatId, username: username);
      }

      if (userId != null && runFunnel) {
        final phase = onboardingState?.phase;
        final resumeAtMap = phase == OnboardingPhase.phase1Map ||
            phase == OnboardingPhase.phase2Activation ||
            phase == OnboardingPhase.phase3Integration ||
            onboardingState?.activationAt != null;
        final resumeAtTrack = phase == OnboardingPhase.phase1Track;
        final resumeAtExperience = phase == OnboardingPhase.phase1Quiz &&
            onboardingState?.step == OnboardingStep.quizExperience;

        if (resumeAtMap || onboardingState?.selectedTrack != null) {
          await _sendMapCta(
            chatId: chatId,
            userId: userId,
            flowByUserId: flowByUserId,
            onboardingService: onboardingService,
            onboardingRepository: onboardingRepository,
            sender: sender,
            templates: templates,
            starterBonusAvailable: starterBonusAvailable,
          );
        } else if (resumeAtTrack) {
          flowByUserId[userId] = const PrivateFlowState(
            step: PrivateFlowStep.onboardingTrack,
            availableTrainings: <TrainingInfo>[],
          );
          await sender.sendMessage(
            chatId,
            templates.onboardingTrackChoice(),
            replyMarkup: templates.onboardingTrackKeyboard(),
          );
        } else if (resumeAtExperience) {
          flowByUserId[userId] = const PrivateFlowState(
            step: PrivateFlowStep.onboardingQuizExperience,
            availableTrainings: <TrainingInfo>[],
          );
          await sender.sendMessage(
            chatId,
            templates.onboardingQuizExperience(),
            replyMarkup: templates.onboardingQuizExperienceKeyboard(),
          );
        } else {
          flowByUserId[userId] = const PrivateFlowState(
            step: PrivateFlowStep.onboardingWelcome,
            availableTrainings: <TrainingInfo>[],
          );
          await onboardingRepository.updateOnboardingProgress(
            userId: userId,
            phase: OnboardingPhase.phase1Quiz,
            step: OnboardingStep.welcome,
          );
          await sender.sendMessage(
            chatId,
            templates.onboardingWelcome(),
            replyMarkup: templates.onboardingContinueKeyboard(),
          );
        }

        if (startPayload == 'book') {
          await sender.sendMessage(
            chatId,
            'Сначала короткий старт — пара вопросов, затем запись.\n'
            'Или нажми «${MessageTemplates.buttonOnboardingSkipQuiz}».',
            replyMarkup: templates.onboardingContinueKeyboard(),
          );
        }
        return true;
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
        await onOpenBookingCategories(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        );
      }
      return true;
    }

    if (text.startsWith('/trainings') || (text == MessageTemplates.buttonTrainings && !isAdmin)) {
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

  static Future<void> _sendMapCta({
    required int chatId,
    required int userId,
    required Map<int, PrivateFlowState> flowByUserId,
    required OnboardingService onboardingService,
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required bool starterBonusAvailable,
  }) async {
    final state = await onboardingRepository.getOnboardingState(userId);
    final outdoor = state?.selectedTrack == OnboardingTrack.outdoor;
    flowByUserId[userId] = const PrivateFlowState(
      step: PrivateFlowStep.onboardingMap,
      availableTrainings: <TrainingInfo>[],
    );
    await onboardingService.markMapShown(userId);
    await sender.sendMessage(
      chatId,
      templates.onboardingClubMap(starterBonusAvailable: starterBonusAvailable),
      replyMarkup: templates.onboardingMapCtaKeyboard(outdoorTrack: outdoor),
    );
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
