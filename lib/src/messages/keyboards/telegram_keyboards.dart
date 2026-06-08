import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';

final class TelegramKeyboards {
  const TelegramKeyboards._();

  static Map<String, Object?> _replyKeyboard(List<List<Map<String, String>>> rows) {
    return <String, Object?>{
      'keyboard': rows,
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  static Map<String, Object?> privateMenuKeyboard({required bool isAdmin}) {
    if (isAdmin) {
      return _replyKeyboard(
        <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonRefreshSchedule},
            <String, String>{'text': MessageCopy.buttonPaymentsQueue},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonAdminSummary},
            <String, String>{'text': MessageCopy.buttonParticipantsList},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonNoblesList},
            <String, String>{'text': MessageCopy.buttonManageBookings},
          ],
        ],
      );
    }

    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonTrainings},
        <String, String>{'text': MessageCopy.buttonBookTraining},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonCoachingStaff},
        <String, String>{'text': MessageCopy.buttonMyBookings},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonHelp},
      ],
    ];
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> bookingSelectionKeyboard(List<TrainingInfo> items) {
    final rows = <List<Map<String, String>>>[];
    for (var index = 0; index < items.length; index++) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': '🎯 ${index + 1}. ${items[index].title}'},
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBack},
        <String, String>{'text': MessageCopy.buttonMainMenu},
      ],
    );
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> categorySelectionKeyboard({
    String trainingsLabel = MessageCopy.buttonCategoryTrainings,
    String hikesLabel = MessageCopy.buttonCategoryHikes,
    String trailsLabel = MessageCopy.buttonCategoryTrails,
  }) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': trainingsLabel},
          <String, String>{'text': hikesLabel},
        ],
        <Map<String, String>>[
          <String, String>{'text': trailsLabel},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> scheduleCategoryActionsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBookTraining},
          <String, String>{'text': MessageCopy.buttonBack},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> paymentConfirmationKeyboard({
    required bool showStarterBonus,
  }) {
    final rows = <List<Map<String, String>>>[];
    if (showStarterBonus) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonUseStarterBonus},
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonSubmitPayment},
      ],
    );
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBack},
        <String, String>{'text': MessageCopy.buttonMainMenu},
      ],
    );
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> bookingManagementSelectionKeyboard(
    List<TrainingBooking> bookings,
  ) {
    final rows = <List<Map<String, String>>>[];
    for (final booking in bookings) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': '🧾 #${booking.id} ${booking.trainingTitle}'},
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBack},
        <String, String>{'text': MessageCopy.buttonMainMenu},
      ],
    );
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> bookingActionsKeyboard({
    required bool canReschedule,
    required bool canCancel,
    required bool canRepeat,
  }) {
    final rows = <List<Map<String, String>>>[];
    if (canReschedule) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonRescheduleBooking},
        ],
      );
    }
    if (canCancel) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonCancelBooking},
        ],
      );
    }
    if (canRepeat) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonRepeatBooking},
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBack},
        <String, String>{'text': MessageCopy.buttonMainMenu},
      ],
    );
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> paymentDecisionInlineKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': '✅ Подтвердить',
            'callback_data': '${MessageCopy.callbackApprovePaymentPrefix}$bookingId',
          },
          <String, String>{
            'text': '❌ Отклонить',
            'callback_data': '${MessageCopy.callbackRejectPaymentPrefix}$bookingId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> openPaymentsQueueInlineKeyboard({
    String buttonLabel = MessageCopy.buttonPaymentsQueue,
  }) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': buttonLabel,
            'callback_data': MessageCopy.callbackOpenPaymentsQueue,
          },
        ],
      ],
    };
  }

  static Map<String, Object?> adminBookingManagementKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBookingsList},
          <String, String>{'text': MessageCopy.buttonCreateBooking},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> bookingSegmentKeyboard({
    required int activeCount,
    required int archivedCount,
  }) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': '${MessageCopy.buttonActiveBookings} ($activeCount)'},
          <String, String>{'text': '${MessageCopy.buttonArchivedBookings} ($archivedCount)'},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminBookingActionsKeyboard({
    required bool canRestore,
  }) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonEditBooking},
          <String, String>{'text': MessageCopy.buttonDeleteBooking},
        ],
        if (canRestore)
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonRestoreBooking},
          ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminBookingEditFieldsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonEditBookingPayment},
          <String, String>{'text': MessageCopy.buttonEditBookingUsername},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonEditBookingEvent},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminBookingDeleteConfirmKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonConfirmDeleteBooking},
          <String, String>{'text': MessageCopy.buttonCancelDeleteBooking},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminBookingAfterActionKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBackToBookingsList},
          <String, String>{'text': MessageCopy.buttonCreateAnotherBooking},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminCreateBookingConfirmationKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonConfirmCreateBooking},
          <String, String>{'text': MessageCopy.buttonCancelCreateBooking},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> bookingPaymentStatusKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonStatusPendingPayment},
          <String, String>{'text': MessageCopy.buttonStatusPaymentSubmitted},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonStatusPaid},
          <String, String>{'text': MessageCopy.buttonStatusPaymentRejected},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }
}
