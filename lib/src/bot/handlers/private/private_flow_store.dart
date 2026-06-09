import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

const Object _privateFlowUnset = Object();

enum PrivateFlowStep {
  selectingScheduleCategory,
  viewingScheduleCategory,
  selectingBookingCategory,
  selectingParticipantsCategory,
  selectingPaymentsQueueCategory,
  selectingEconomicSummaryPeriod,
  selectingTraining,
  paymentConfirmation,
  selectingBookingToManage,
  selectingBookingAction,
  selectingRescheduleTraining,
  selectingAdminBookingManagementAction,
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

final class PrivateFlowState {
  const PrivateFlowState({
    required this.step,
    required this.availableTrainings,
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
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
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

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
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
  }) {
    return PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
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
    );
  }
}
