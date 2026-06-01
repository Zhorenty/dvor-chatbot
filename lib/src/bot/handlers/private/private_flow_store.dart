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
  });

  final PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final TrainingBooking? activeBooking;

  PrivateFlowState copyWith({
    PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    TrainingBooking? activeBooking,
  }) {
    return PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
      activeBooking: activeBooking ?? this.activeBooking,
    );
  }
}
