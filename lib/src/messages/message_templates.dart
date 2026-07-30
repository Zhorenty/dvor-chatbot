import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/keyboards/telegram_keyboards.dart';
import 'package:dvor_chatbot/src/messages/templates/group_templates.dart';
import 'package:dvor_chatbot/src/messages/templates/private_navigation_templates.dart';
import 'package:dvor_chatbot/src/messages/templates/schedule_templates.dart';
import 'package:intl/intl.dart';

part 'templates/message_templates_content.part.dart';
part 'templates/message_templates_keyboards.part.dart';
part 'templates/message_templates_helpers.part.dart';

final class MessageTemplates {
  const MessageTemplates({
    String? botUsername,
  }) : _botUsername = botUsername;

  final String? _botUsername;
  final PrivateNavigationTemplates _privateNavigationTemplates = const PrivateNavigationTemplates();
  final ScheduleTemplates _scheduleTemplates = const ScheduleTemplates();
  GroupTemplates get _groupTemplates => GroupTemplates(botUsername: _botUsername);

  static const String buttonDvorXFrank = MessageCopy.buttonDvorXFrank;
  static const String buttonTrainings = MessageCopy.buttonTrainings;
  static const String buttonCoachingStaff = MessageCopy.buttonCoachingStaff;
  static const String buttonCoachDetails = MessageCopy.buttonCoachDetails;
  static const String buttonBookTraining = MessageCopy.buttonBookTraining;
  static const String buttonBookFriend = MessageCopy.buttonBookFriend;
  static const String buttonSubscription = MessageCopy.buttonSubscription;
  static const String buttonProfile = MessageCopy.buttonProfile;
  static const String buttonProfileBookings = MessageCopy.buttonProfileBookings;
  static const String buttonReferralProgram = MessageCopy.buttonReferralProgram;
  static const String buttonSubmitPayment = MessageCopy.buttonSubmitPayment;
  static const String buttonPayFully = MessageCopy.buttonPayFully;
  static const String buttonPayPartially = MessageCopy.buttonPayPartially;
  static const String buttonUseStarterBonus = MessageCopy.buttonUseStarterBonus;
  static const String buttonEnterPromoCode = MessageCopy.buttonEnterPromoCode;
  static const String buttonRescheduleBooking = MessageCopy.buttonRescheduleBooking;
  static const String buttonRepeatBooking = MessageCopy.buttonRepeatBooking;
  static const String buttonContinuePayment = MessageCopy.buttonContinuePayment;
  static const String buttonCompletePayment = MessageCopy.buttonCompletePayment;
  static const String buttonCancelBooking = MessageCopy.buttonCancelBooking;
  static const String buttonConfirmCancelBooking = MessageCopy.buttonConfirmCancelBooking;
  static const String buttonKeepBooking = MessageCopy.buttonKeepBooking;
  static const String buttonBack = MessageCopy.buttonBack;
  static const String buttonMainMenu = MessageCopy.buttonMainMenu;
  static const String buttonHelp = MessageCopy.buttonHelp;
  static const String buttonOnboardingContinue = MessageCopy.buttonOnboardingContinue;
  static const String buttonOnboardingNeedHelp = MessageCopy.buttonOnboardingNeedHelp;
  static const String buttonOnboardingNeedMoreTime = MessageCopy.buttonOnboardingNeedMoreTime;
  static const String buttonOnboardingSkipQuiz = MessageCopy.buttonOnboardingSkipQuiz;
  static const String buttonQuizGoalForm = MessageCopy.buttonQuizGoalForm;
  static const String buttonQuizGoalEndurance = MessageCopy.buttonQuizGoalEndurance;
  static const String buttonQuizGoalYoga = MessageCopy.buttonQuizGoalYoga;
  static const String buttonQuizGoalOutdoor = MessageCopy.buttonQuizGoalOutdoor;
  static const String buttonQuizGoalUnknown = MessageCopy.buttonQuizGoalUnknown;
  static const String buttonQuizExpBeginner = MessageCopy.buttonQuizExpBeginner;
  static const String buttonQuizExpReturning = MessageCopy.buttonQuizExpReturning;
  static const String buttonQuizExpRegular = MessageCopy.buttonQuizExpRegular;
  static const String buttonTrackOneOff = MessageCopy.buttonTrackOneOff;
  static const String buttonTrackOutdoor = MessageCopy.buttonTrackOutdoor;
  static const String buttonFeedbackGreat = MessageCopy.buttonFeedbackGreat;
  static const String buttonFeedbackOk = MessageCopy.buttonFeedbackOk;
  static const String buttonFeedbackWeak = MessageCopy.buttonFeedbackWeak;
  static const String buttonFeedbackSkip = MessageCopy.buttonFeedbackSkip;
  static const String buttonCategoryTrainings = MessageCopy.buttonCategoryTrainings;
  static const String buttonCategoryYoga = MessageCopy.buttonCategoryYoga;
  static const String buttonCategoryHikes = MessageCopy.buttonCategoryHikes;
  static const String buttonCategoryTrails = MessageCopy.buttonCategoryTrails;
  static const String buttonOutdoorEquipment = MessageCopy.buttonOutdoorEquipment;
  static const String buttonOutdoorItinerary = MessageCopy.buttonOutdoorItinerary;
  static const String buttonRefreshSchedule = MessageCopy.buttonRefreshSchedule;
  static const String buttonPaymentsQueue = MessageCopy.buttonPaymentsQueue;
  static const String buttonAdminAnalytics = MessageCopy.buttonAdminAnalytics;
  static const String buttonEconomicSummary = MessageCopy.buttonEconomicSummary;
  static const String buttonFunnelAnalytics = MessageCopy.buttonFunnelAnalytics;
  static const String buttonFeedbackAnalytics = MessageCopy.buttonFeedbackAnalytics;
  static const String buttonBookingAnalytics = MessageCopy.buttonBookingAnalytics;
  static const String buttonLoyaltyAnalytics = MessageCopy.buttonLoyaltyAnalytics;
  static const String buttonSubscriptionAnalytics = MessageCopy.buttonSubscriptionAnalytics;
  static const String buttonSubscriptionsAdmin = MessageCopy.buttonSubscriptionsAdmin;
  static const String buttonSubscriptionsList = MessageCopy.buttonSubscriptionsList;
  static const String buttonSubscribersManagement = MessageCopy.buttonSubscribersManagement;
  static const String buttonSubscribeApply = MessageCopy.buttonSubscribeApply;
  static const String buttonRenewSubscription = MessageCopy.buttonRenewSubscription;
  static const String buttonSubscriptionsFilterActive = MessageCopy.buttonSubscriptionsFilterActive;
  static const String buttonSubscriptionsFilterExpiring =
      MessageCopy.buttonSubscriptionsFilterExpiring;
  static const String buttonSubscriptionsFilterPending =
      MessageCopy.buttonSubscriptionsFilterPending;
  static const String buttonSubscriptionsFilterCancelled =
      MessageCopy.buttonSubscriptionsFilterCancelled;
  static const String buttonSubscriptionsSearch = MessageCopy.buttonSubscriptionsSearch;
  static const String buttonSkipComment = MessageCopy.buttonSkipComment;
  static const String buttonReasonNotConfirmed = MessageCopy.buttonReasonNotConfirmed;
  static const String buttonReasonWrongAmount = MessageCopy.buttonReasonWrongAmount;
  static const String buttonReasonDuplicate = MessageCopy.buttonReasonDuplicate;
  static const String buttonParticipantsList = MessageCopy.buttonParticipantsList;
  static const String buttonNoblesList = MessageCopy.buttonNoblesList;
  static const String buttonBroadcast = MessageCopy.buttonBroadcast;
  static const String buttonAdminTools = MessageCopy.buttonAdminTools;
  static const String buttonClientMenu = MessageCopy.buttonClientMenu;
  static const String buttonAdminMenu = MessageCopy.buttonAdminMenu;
  static const String buttonAdminUserSearch = MessageCopy.buttonAdminUserSearch;
  static const String buttonAdminRecentActions = MessageCopy.buttonAdminRecentActions;
  static const String buttonAdminUserDialog = MessageCopy.buttonAdminUserDialog;
  static const String buttonManageBookings = MessageCopy.buttonManageBookings;
  static const String buttonBookingsList = MessageCopy.buttonBookingsList;
  static const String buttonCreateBooking = MessageCopy.buttonCreateBooking;
  static const String buttonActiveBookings = MessageCopy.buttonActiveBookings;
  static const String buttonArchivedBookings = MessageCopy.buttonArchivedBookings;
  static const String buttonEditBooking = MessageCopy.buttonEditBooking;
  static const String buttonDeleteBooking = MessageCopy.buttonDeleteBooking;
  static const String buttonRestoreBooking = MessageCopy.buttonRestoreBooking;
  static const String buttonEditBookingPayment = MessageCopy.buttonEditBookingPayment;
  static const String buttonEditBookingUsername = MessageCopy.buttonEditBookingUsername;
  static const String buttonEditBookingEvent = MessageCopy.buttonEditBookingEvent;
  static const String buttonConfirmDeleteBooking = MessageCopy.buttonConfirmDeleteBooking;
  static const String buttonCancelDeleteBooking = MessageCopy.buttonCancelDeleteBooking;
  static const String buttonBackToBookingsList = MessageCopy.buttonBackToBookingsList;
  static const String buttonBookingsPreviousPage = MessageCopy.buttonBookingsPreviousPage;
  static const String buttonBookingsNextPage = MessageCopy.buttonBookingsNextPage;
  static const String buttonCurrentBookings = MessageCopy.buttonCurrentBookings;
  static const String buttonPastBookings = MessageCopy.buttonPastBookings;
  static const String buttonCreateAnotherBooking = MessageCopy.buttonCreateAnotherBooking;
  static const String buttonConfirmCreateBooking = MessageCopy.buttonConfirmCreateBooking;
  static const String buttonCancelCreateBooking = MessageCopy.buttonCancelCreateBooking;
  static const String buttonNotifyClientYes = MessageCopy.buttonNotifyClientYes;
  static const String buttonNotifyClientNo = MessageCopy.buttonNotifyClientNo;
  static const String buttonStatusPendingPayment = MessageCopy.buttonStatusPendingPayment;
  static const String buttonStatusPaymentSubmitted = MessageCopy.buttonStatusPaymentSubmitted;
  static const String buttonStatusPartialPaid = MessageCopy.buttonStatusPartialPaid;
  static const String buttonStatusPaid = MessageCopy.buttonStatusPaid;
  static const String buttonStatusFreeTraining = MessageCopy.buttonStatusFreeTraining;
  static const String buttonStatusPaymentRejected = MessageCopy.buttonStatusPaymentRejected;
  static const String buttonSummaryCurrentWeek = MessageCopy.buttonSummaryCurrentWeek;
  static const String buttonSummaryPreviousWeek = MessageCopy.buttonSummaryPreviousWeek;
  static const String buttonSummaryCurrentMonth = MessageCopy.buttonSummaryCurrentMonth;
  static const String buttonSummaryPreviousMonth = MessageCopy.buttonSummaryPreviousMonth;
  static const String callbackApprovePaymentPrefix = MessageCopy.callbackApprovePaymentPrefix;
  static const String callbackApprovePartialPaymentPrefix =
      MessageCopy.callbackApprovePartialPaymentPrefix;
  static const String callbackRejectPaymentPrefix = MessageCopy.callbackRejectPaymentPrefix;
  static const String callbackPayBookingPrefix = MessageCopy.callbackPayBookingPrefix;
  static const String callbackOpenPaymentsQueue = MessageCopy.callbackOpenPaymentsQueue;
  static const String callbackNextPaymentInQueuePrefix =
      MessageCopy.callbackNextPaymentInQueuePrefix;
  static const String callbackApproveSubscriptionPrefix =
      MessageCopy.callbackApproveSubscriptionPrefix;
  static const String callbackRejectSubscriptionPrefix =
      MessageCopy.callbackRejectSubscriptionPrefix;
  static const String callbackCancelSubscriptionPrefix =
      MessageCopy.callbackCancelSubscriptionPrefix;
  static const String scheduleDocumentUrl = MessageCopy.scheduleDocumentUrl;

  String privateWelcome() {
    return _privateNavigationTemplates.privateWelcome();
  }

  String starterBonusOnboardingOffer() {
    return _privateNavigationTemplates.starterBonusOnboardingOffer();
  }

  String onboardingWelcome() => _privateNavigationTemplates.onboardingWelcome();

  String onboardingQuizGoal() => _privateNavigationTemplates.onboardingQuizGoal();

  String onboardingQuizExperience() => _privateNavigationTemplates.onboardingQuizExperience();

  String onboardingTrackChoice() => _privateNavigationTemplates.onboardingTrackChoice();

  String onboardingClubMap({required bool starterBonusAvailable}) {
    return _privateNavigationTemplates.onboardingClubMap(
      starterBonusAvailable: starterBonusAvailable,
    );
  }

  String onboardingNeedHelp() => _privateNavigationTemplates.onboardingNeedHelp();

  String onboardingNudgeQuizReminder() => _privateNavigationTemplates.onboardingNudgeQuizReminder();

  String onboardingNudgePrimaryCta() => _privateNavigationTemplates.onboardingNudgePrimaryCta();

  String onboardingNudgeDay5Alt() => _privateNavigationTemplates.onboardingNudgeDay5Alt();

  String onboardingNudgeDay7() => _privateNavigationTemplates.onboardingNudgeDay7();

  String onboardingActivationSuccess() => _privateNavigationTemplates.onboardingActivationSuccess();

  String onboardingSnoozeAck() => _privateNavigationTemplates.onboardingSnoozeAck();

  String trainingFeedbackAsk({required String trainingTitle}) {
    return _privateNavigationTemplates.trainingFeedbackAsk(trainingTitle: trainingTitle);
  }

  String trainingFeedbackCommentAsk() => _privateNavigationTemplates.trainingFeedbackCommentAsk();

  String trainingFeedbackThanks() => _privateNavigationTemplates.trainingFeedbackThanks();

  String trainingFeedbackAdminNotification({
    required String trainingTitle,
    required TrainingFeedbackRating rating,
    String? comment,
  }) {
    return _privateNavigationTemplates.trainingFeedbackAdminNotification(
      trainingTitle: _escapeHtml(trainingTitle),
      ratingLabel: _escapeHtml(_feedbackRatingLabel(rating.storageValue)),
      comment: comment == null ? null : _escapeHtml(comment),
    );
  }

  String privateHelp() {
    return _privateNavigationTemplates.privateHelp();
  }

  String dvorXFrankPromo() {
    return _privateNavigationTemplates.dvorXFrankPromo();
  }

  String privateFallback() {
    return _privateNavigationTemplates.privateFallback();
  }
}
