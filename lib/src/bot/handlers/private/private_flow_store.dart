import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
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
  selectingBookingCategory,
  selectingParticipantsCategory,
  selectingPaymentsQueueCategory,
  selectingEconomicSummaryPeriod,
  viewingSubscriptionOverview,
  confirmingSubscriptionPayment,
  selectingTraining,
  selectingBookingListSegment,
  paymentConfirmation,
  selectingBookingToManage,
  selectingBookingAction,
  selectingRescheduleTraining,
  selectingAdminBookingManagementAction,
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
}

enum PaymentChoice {
  full,
  partial,
}

enum SubscriptionModerationAction {
  reject,
  cancel,
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
    this.bookingFromSchedulePreview = false,
    this.starterBonusOffered = false,
    this.adminViewingArchived = false,
    this.adminCreateStatus,
    this.adminCreateUsername,
    this.adminCreateTraining,
    this.paymentChoice,
    this.adminBookingsPage = 0,
    this.adminSubscriptionFilter = SubscriptionListFilter.active,
    this.subscriptionModerationAction,
    this.subscriptionModerationRequestId,
    this.subscriptionModerationReason,
    this.subscriptionSearchQuery,
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final List<TrainerInfo> availableTrainers;
  final List<TrainingBooking> availableBookings;
  final TrainingBooking? activeBooking;
  final TrainingBooking? selectedBooking;
  final ActivityCategory? selectedCategory;
  final bool bookingFromSchedulePreview;
  final bool starterBonusOffered;
  final bool adminViewingArchived;
  final BookingStatus? adminCreateStatus;
  final String? adminCreateUsername;
  final TrainingInfo? adminCreateTraining;
  final PaymentChoice? paymentChoice;
  final int adminBookingsPage;
  final SubscriptionListFilter adminSubscriptionFilter;
  final SubscriptionModerationAction? subscriptionModerationAction;
  final int? subscriptionModerationRequestId;
  final String? subscriptionModerationReason;
  final String? subscriptionSearchQuery;

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    List<TrainerInfo>? availableTrainers,
    List<TrainingBooking>? availableBookings,
    Object? activeBooking = _privateFlowUnset,
    Object? selectedBooking = _privateFlowUnset,
    Object? selectedCategory = _privateFlowUnset,
    bool? bookingFromSchedulePreview,
    bool? starterBonusOffered,
    bool? adminViewingArchived,
    Object? adminCreateStatus = _privateFlowUnset,
    Object? adminCreateUsername = _privateFlowUnset,
    Object? adminCreateTraining = _privateFlowUnset,
    Object? paymentChoice = _privateFlowUnset,
    int? adminBookingsPage,
    SubscriptionListFilter? adminSubscriptionFilter,
    Object? subscriptionModerationAction = _privateFlowUnset,
    Object? subscriptionModerationRequestId = _privateFlowUnset,
    Object? subscriptionModerationReason = _privateFlowUnset,
    Object? subscriptionSearchQuery = _privateFlowUnset,
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
      bookingFromSchedulePreview: bookingFromSchedulePreview ?? this.bookingFromSchedulePreview,
      starterBonusOffered: starterBonusOffered ?? this.starterBonusOffered,
      adminViewingArchived: adminViewingArchived ?? this.adminViewingArchived,
      adminCreateStatus: identical(adminCreateStatus, _privateFlowUnset)
          ? this.adminCreateStatus
          : adminCreateStatus as BookingStatus?,
      adminCreateUsername: identical(adminCreateUsername, _privateFlowUnset)
          ? this.adminCreateUsername
          : adminCreateUsername as String?,
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
    );
  }
}
