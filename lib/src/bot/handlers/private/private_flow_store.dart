import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

enum PrivateFlowStep {
  selectingScheduleCategory,
  selectingBookingCategory,
  selectingParticipantsCategory,
  selectingPaymentsQueueCategory,
  selectingTraining,
  paymentConfirmation,
  selectingBookingToManage,
  selectingBookingAction,
  selectingRescheduleTraining,
}

final class PrivateFlowState {
  const PrivateFlowState({
    required this.step,
    required this.availableTrainings,
    this.availableBookings = const <TrainingBooking>[],
    this.activeBooking,
    this.selectedBooking,
    this.starterBonusOffered = false,
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final List<TrainingBooking> availableBookings;
  final TrainingBooking? activeBooking;
  final TrainingBooking? selectedBooking;
  final bool starterBonusOffered;

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    List<TrainingBooking>? availableBookings,
    TrainingBooking? activeBooking,
    TrainingBooking? selectedBooking,
    bool? starterBonusOffered,
  }) {
    return PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
      availableBookings: availableBookings ?? this.availableBookings,
      activeBooking: activeBooking ?? this.activeBooking,
      selectedBooking: selectedBooking ?? this.selectedBooking,
      starterBonusOffered: starterBonusOffered ?? this.starterBonusOffered,
    );
  }
}
