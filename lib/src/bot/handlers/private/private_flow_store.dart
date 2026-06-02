import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

enum PrivateFlowStep {
  selectingScheduleCategory,
  selectingBookingCategory,
  selectingParticipantsCategory,
  selectingPaymentsQueueCategory,
  selectingTraining,
  paymentConfirmation,
}

final class PrivateFlowState {
  const PrivateFlowState({
    required this.step,
    required this.availableTrainings,
    this.activeBooking,
    this.starterBonusOffered = false,
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final TrainingBooking? activeBooking;
  final bool starterBonusOffered;

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    TrainingBooking? activeBooking,
    bool? starterBonusOffered,
  }) {
    return PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
      activeBooking: activeBooking ?? this.activeBooking,
      starterBonusOffered: starterBonusOffered ?? this.starterBonusOffered,
    );
  }
}
