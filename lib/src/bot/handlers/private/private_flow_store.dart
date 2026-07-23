import 'package:dvor_chatbot/src/application/broadcast_service.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

const Object _privateFlowUnset = Object();

enum PrivateFlowStep {
  selectingScheduleCategory,
  viewingCoachingStaff,
  selectingTrainerProfile,
  viewingScheduleCategory,
  selectingOutdoorDetailEvent,
  selectingOutdoorDetailType,
  selectingBookingCategory,
  selectingParticipantsCategory,
  selectingPaymentsQueueCategory,
  selectingEconomicSummaryPeriod,
  viewingSubscriptionOverview,
  confirmingSubscriptionPayment,
  selectingTraining,
  selectingBookingListSegment,
  paymentConfirmation,
  enteringPromoCode,
  selectingBookingToManage,
  selectingBookingAction,
  selectingRescheduleTraining,
  selectingAdminBookingManagementAction,
  selectingAdminToolsAction,
  selectingAdminSubscriptionsAction,
  selectingAdminSubscriptionFilter,
  enteringAdminSubscriptionSearchQuery,
  selectingAdminSubscriptionReasonTemplate,
  enteringAdminSubscriptionReasonComment,
  selectingAdminBookingListSegment,
  selectingAdminBookingListCategory,
  selectingAdminBookingFromList,
  selectingAdminBookingAction,
  selectingAdminBookingEditField,
  selectingAdminBookingEditStatus,
  enteringAdminBookingUsername,
  selectingAdminBookingEditEvent,
  confirmingAdminBookingDelete,
  selectingAdminCreateCategory,
  selectingAdminCreateEvent,
  enteringAdminCreateUsername,
  selectingAdminCreateStatus,
  confirmingAdminCreate,
  selectingAdminClientNotificationPreference,
  enteringAdminBroadcastText,
  selectingAdminBroadcastTarget,
  enteringAdminUserSearchQuery,
}

enum PaymentChoice {
  full,
  partial,
}

enum OutdoorDetailType {
  equipment,
  itinerary,
}

enum SubscriptionModerationAction {
  reject,
  cancel,
}

enum AdminClientNotificationAction {
  bookingCreated,
  bookingDeleted,
  bookingRestored,
  bookingStatusUpdated,
  bookingUsernameUpdated,
  bookingEventUpdated,
}

final class PrivateFlowState {
  const PrivateFlowState({
    required this.step,
    required this.availableTrainings,
    this.availableTrainers = const <TrainerInfo>[],
    this.availableBookings = const <TrainingBooking>[],
    this.activeBooking,
    this.selectedBooking,
    this.selectedCategory,
    this.selectedOutdoorActivity,
    this.bookingFromSchedulePreview = false,
    this.starterBonusOffered = false,
    this.adminViewingArchived = false,
    this.adminCreateStatus,
    this.adminCreateUsernames,
    this.adminCreateTraining,
    this.paymentChoice,
    this.adminBookingsPage = 0,
    this.adminSubscriptionFilter = SubscriptionListFilter.active,
    this.subscriptionModerationAction,
    this.subscriptionModerationRequestId,
    this.subscriptionModerationReason,
    this.subscriptionSearchQuery,
    this.outdoorDetailType,
    this.adminClientNotificationAction,
    this.adminClientNotificationBooking,
    this.adminBroadcastText,
    this.adminBroadcastSourceMessages = const <BroadcastMessageRef>[],
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final List<TrainerInfo> availableTrainers;
  final List<TrainingBooking> availableBookings;
  final TrainingBooking? activeBooking;
  final TrainingBooking? selectedBooking;
  final ActivityCategory? selectedCategory;
  final OutdoorActivityInfo? selectedOutdoorActivity;
  final bool bookingFromSchedulePreview;
  final bool starterBonusOffered;
  final bool adminViewingArchived;
  final BookingStatus? adminCreateStatus;
  final List<String>? adminCreateUsernames;
  final TrainingInfo? adminCreateTraining;
  final PaymentChoice? paymentChoice;
  final int adminBookingsPage;
  final SubscriptionListFilter adminSubscriptionFilter;
  final SubscriptionModerationAction? subscriptionModerationAction;
  final int? subscriptionModerationRequestId;
  final String? subscriptionModerationReason;
  final String? subscriptionSearchQuery;
  final OutdoorDetailType? outdoorDetailType;
  final AdminClientNotificationAction? adminClientNotificationAction;
  final TrainingBooking? adminClientNotificationBooking;
  final String? adminBroadcastText;
  final List<BroadcastMessageRef> adminBroadcastSourceMessages;

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    List<TrainerInfo>? availableTrainers,
    List<TrainingBooking>? availableBookings,
    Object? activeBooking = _privateFlowUnset,
    Object? selectedBooking = _privateFlowUnset,
    Object? selectedCategory = _privateFlowUnset,
    Object? selectedOutdoorActivity = _privateFlowUnset,
    bool? bookingFromSchedulePreview,
    bool? starterBonusOffered,
    bool? adminViewingArchived,
    Object? adminCreateStatus = _privateFlowUnset,
    Object? adminCreateUsernames = _privateFlowUnset,
    Object? adminCreateTraining = _privateFlowUnset,
    Object? paymentChoice = _privateFlowUnset,
    int? adminBookingsPage,
    SubscriptionListFilter? adminSubscriptionFilter,
    Object? subscriptionModerationAction = _privateFlowUnset,
    Object? subscriptionModerationRequestId = _privateFlowUnset,
    Object? subscriptionModerationReason = _privateFlowUnset,
    Object? subscriptionSearchQuery = _privateFlowUnset,
    Object? outdoorDetailType = _privateFlowUnset,
    Object? adminClientNotificationAction = _privateFlowUnset,
    Object? adminClientNotificationBooking = _privateFlowUnset,
    Object? adminBroadcastText = _privateFlowUnset,
    List<BroadcastMessageRef>? adminBroadcastSourceMessages,
  }) {
    return PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
      availableTrainers: availableTrainers ?? this.availableTrainers,
      availableBookings: availableBookings ?? this.availableBookings,
      activeBooking: identical(activeBooking, _privateFlowUnset)
          ? this.activeBooking
          : activeBooking as TrainingBooking?,
      selectedBooking: identical(selectedBooking, _privateFlowUnset)
          ? this.selectedBooking
          : selectedBooking as TrainingBooking?,
      selectedCategory: identical(selectedCategory, _privateFlowUnset)
          ? this.selectedCategory
          : selectedCategory as ActivityCategory?,
      selectedOutdoorActivity: identical(selectedOutdoorActivity, _privateFlowUnset)
          ? this.selectedOutdoorActivity
          : selectedOutdoorActivity as OutdoorActivityInfo?,
      bookingFromSchedulePreview: bookingFromSchedulePreview ?? this.bookingFromSchedulePreview,
      starterBonusOffered: starterBonusOffered ?? this.starterBonusOffered,
      adminViewingArchived: adminViewingArchived ?? this.adminViewingArchived,
      adminCreateStatus: identical(adminCreateStatus, _privateFlowUnset)
          ? this.adminCreateStatus
          : adminCreateStatus as BookingStatus?,
      adminCreateUsernames: identical(adminCreateUsernames, _privateFlowUnset)
          ? this.adminCreateUsernames
          : adminCreateUsernames as List<String>?,
      adminCreateTraining: identical(adminCreateTraining, _privateFlowUnset)
          ? this.adminCreateTraining
          : adminCreateTraining as TrainingInfo?,
      paymentChoice: identical(paymentChoice, _privateFlowUnset)
          ? this.paymentChoice
          : paymentChoice as PaymentChoice?,
      adminBookingsPage: adminBookingsPage ?? this.adminBookingsPage,
      adminSubscriptionFilter: adminSubscriptionFilter ?? this.adminSubscriptionFilter,
      subscriptionModerationAction: identical(subscriptionModerationAction, _privateFlowUnset)
          ? this.subscriptionModerationAction
          : subscriptionModerationAction as SubscriptionModerationAction?,
      subscriptionModerationRequestId: identical(subscriptionModerationRequestId, _privateFlowUnset)
          ? this.subscriptionModerationRequestId
          : subscriptionModerationRequestId as int?,
      subscriptionModerationReason: identical(subscriptionModerationReason, _privateFlowUnset)
          ? this.subscriptionModerationReason
          : subscriptionModerationReason as String?,
      subscriptionSearchQuery: identical(subscriptionSearchQuery, _privateFlowUnset)
          ? this.subscriptionSearchQuery
          : subscriptionSearchQuery as String?,
      outdoorDetailType: identical(outdoorDetailType, _privateFlowUnset)
          ? this.outdoorDetailType
          : outdoorDetailType as OutdoorDetailType?,
      adminClientNotificationAction: identical(adminClientNotificationAction, _privateFlowUnset)
          ? this.adminClientNotificationAction
          : adminClientNotificationAction as AdminClientNotificationAction?,
      adminClientNotificationBooking: identical(adminClientNotificationBooking, _privateFlowUnset)
          ? this.adminClientNotificationBooking
          : adminClientNotificationBooking as TrainingBooking?,
      adminBroadcastText: identical(adminBroadcastText, _privateFlowUnset)
          ? this.adminBroadcastText
          : adminBroadcastText as String?,
      adminBroadcastSourceMessages:
          adminBroadcastSourceMessages ?? this.adminBroadcastSourceMessages,
    );
  }
}
