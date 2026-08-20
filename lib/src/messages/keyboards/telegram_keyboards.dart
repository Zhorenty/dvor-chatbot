import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/keyboards/keyboard_builders.dart';

final class TelegramKeyboards {
  const TelegramKeyboards._();

  static Map<String, Object?> _replyKeyboard(List<List<Map<String, String>>> rows) {
    return replyKeyboard(rows);
  }

  static Map<String, Object?> privateMenuKeyboard({
    required bool isAdmin,
    bool canViewParticipantsList = false,
    bool showReturnToAdminMenu = false,
  }) {
    if (isAdmin) {
      return _replyKeyboard(
        <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonParticipantsList},
            <String, String>{'text': MessageCopy.buttonPaymentsQueue},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonAdminSchedule},
            <String, String>{'text': MessageCopy.buttonBroadcast},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonAdminTools},
          ],
        ],
      );
    }

    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBookTraining},
        <String, String>{'text': MessageCopy.buttonBookFriend},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonCoachingStaff},
        <String, String>{'text': MessageCopy.buttonProfile},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonHelp},
      ],
    ];
    if (canViewParticipantsList) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonParticipantsList},
        ],
      );
    }
    if (showReturnToAdminMenu) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonAdminMenu},
        ],
      );
    }
    return _replyKeyboard(rows);
  }

  static Map<String, Object?> adminToolsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonManageBookings},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonRefreshSchedule},
          <String, String>{'text': MessageCopy.buttonSubscriptionsAdmin},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonAdminUserSearch},
          <String, String>{'text': MessageCopy.buttonAdminUserDialog},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonClientMenu},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminAnalyticsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonFunnelAnalytics},
          <String, String>{'text': MessageCopy.buttonFeedbackAnalytics},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonEconomicSummary},
          <String, String>{'text': MessageCopy.buttonBookingAnalytics},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonLoyaltyAnalytics},
          <String, String>{'text': MessageCopy.buttonSubscriptionAnalytics},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
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
        ],
        <Map<String, String>>[
          <String, String>{'text': hikesLabel},
          <String, String>{'text': trailsLabel},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> scheduleCategoryActionsKeyboard({
    bool showOutdoorActions = false,
  }) {
    if (showOutdoorActions) {
      return _replyKeyboard(
        <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonBookTraining},
            <String, String>{'text': MessageCopy.buttonOutdoorEquipment},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonOutdoorItinerary},
            <String, String>{'text': MessageCopy.buttonBack},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonMainMenu},
          ],
        ],
      );
    }
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

  static Map<String, Object?> coachingStaffActionsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonCoachDetails},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> trainerSelectionKeyboard(List<TrainerInfo> trainers) {
    final rows = <List<Map<String, String>>>[];
    for (var index = 0; index < trainers.length; index++) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': '👤 ${index + 1}. ${trainers[index].name}'},
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

  static Map<String, Object?> outdoorSelectionKeyboard(List<OutdoorActivityInfo> items) {
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

  static Map<String, Object?> outdoorDetailTypeKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBookTraining},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOutdoorItinerary},
          <String, String>{'text': MessageCopy.buttonOutdoorEquipment},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  /// Secondary reply nav for payment step (primary CTAs are inline on the card).
  static Map<String, Object?> paymentConfirmationKeyboard({
    required bool showStarterBonus,
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    final rows = <List<Map<String, String>>>[];
    // Legacy reply actions kept for backward-compatible reply taps during migration.
    if (showStarterBonus) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonUseStarterBonus},
        ],
      );
    }
    if (showOutdoorPaymentTypeChoice) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonPayFully},
          <String, String>{'text': MessageCopy.buttonPayPartially},
        ],
      );
    }
    if (!showOutdoorPaymentTypeChoice) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSubmitPayment},
        ],
      );
    }
    if (showPromoCodeEntry || showCancelBooking) {
      rows.add(
        <Map<String, String>>[
          if (showPromoCodeEntry) <String, String>{'text': MessageCopy.buttonEnterPromoCode},
          if (showCancelBooking) <String, String>{'text': MessageCopy.buttonCancelBooking},
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

  /// Entity-bound payment CTAs under the requisites / reject card.
  static Map<String, Object?> paymentCardInlineKeyboard(
    int bookingId, {
    required bool showStarterBonus,
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    final rows = <List<Map<String, String>>>[];
    if (showOutdoorPaymentTypeChoice) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonPayFully,
            'callback_data': '${MessageCopy.callbackPayFullPrefix}$bookingId',
          },
          <String, String>{
            'text': MessageCopy.buttonPayPartially,
            'callback_data': '${MessageCopy.callbackPayPartialPrefix}$bookingId',
          },
        ],
      );
    } else {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonSubmitPayment,
            'callback_data': '${MessageCopy.callbackPayBookingPrefix}$bookingId',
          },
        ],
      );
    }
    if (showStarterBonus) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonUseStarterBonus,
            'callback_data': '${MessageCopy.callbackUseBonusPrefix}$bookingId',
          },
        ],
      );
    }
    if (showPromoCodeEntry || showCancelBooking) {
      rows.add(
        <Map<String, String>>[
          if (showPromoCodeEntry)
            <String, String>{
              'text': MessageCopy.buttonEnterPromoCode,
              'callback_data': '${MessageCopy.callbackEnterPromoPrefix}$bookingId',
            },
          if (showCancelBooking)
            <String, String>{
              'text': MessageCopy.buttonCancelBooking,
              'callback_data': '${MessageCopy.callbackBookingCancelPrefix}$bookingId',
            },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> simpleNavigationKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> profileActionsKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonProfileBookings},
        ],
        <Map<String, String>>[
          // TODO(subscription): вернуть кнопку абонемента в профиле.
          // <String, String>{'text': MessageCopy.buttonSubscription},
          <String, String>{'text': MessageCopy.buttonReferralProgram},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> subscriptionOverviewKeyboard({
    required bool canApply,
    bool isRenewal = false,
  }) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        if (canApply)
          <Map<String, String>>[
            <String, String>{
              'text': isRenewal
                  ? MessageCopy.buttonRenewSubscription
                  : MessageCopy.buttonSubscribeApply,
            },
          ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> bookingManagementSelectionKeyboard(
    List<TrainingBooking> bookings,
  ) {
    final rows = <List<Map<String, String>>>[];
    for (final booking in bookings) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': _bookingSelectionButtonText(booking)},
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

  static Map<String, Object?> adminBookingSelectionKeyboard(
    List<TrainingBooking> bookings, {
    required bool hasPreviousPage,
    required bool hasNextPage,
  }) {
    final rows = <List<Map<String, String>>>[];
    for (final booking in bookings) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': _bookingSelectionButtonText(booking)},
        ],
      );
    }
    if (hasPreviousPage || hasNextPage) {
      final pageButtons = <Map<String, String>>[];
      if (hasPreviousPage) {
        pageButtons.add(<String, String>{'text': MessageCopy.buttonBookingsPreviousPage});
      }
      if (hasNextPage) {
        pageButtons.add(<String, String>{'text': MessageCopy.buttonBookingsNextPage});
      }
      rows.add(pageButtons);
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
    bool canCompletePayment = false,
    bool canContinuePayment = false,
  }) {
    final rows = <List<Map<String, String>>>[];
    if (canContinuePayment) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonContinuePayment},
        ],
      );
    }
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
    if (canCompletePayment) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonCompletePayment},
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

  static Map<String, Object?> bookingCancelConfirmKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonConfirmCancelBooking},
          <String, String>{'text': MessageCopy.buttonKeepBooking},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> bookingCancelConfirmInlineKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonConfirmCancelBooking,
            'callback_data': '${MessageCopy.callbackBookingCancelConfirmPrefix}$bookingId',
          },
          <String, String>{
            'text': MessageCopy.buttonKeepBooking,
            'callback_data': '${MessageCopy.callbackBookingCancelKeepPrefix}$bookingId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> bookingActionsInlineKeyboard({
    required int bookingId,
    required bool canReschedule,
    required bool canCancel,
    required bool canRepeat,
    bool canCompletePayment = false,
    bool canContinuePayment = false,
  }) {
    final rows = <List<Map<String, String>>>[];
    if (canContinuePayment) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonContinuePayment,
            'callback_data': '${MessageCopy.callbackBookingContinuePayPrefix}$bookingId',
          },
        ],
      );
    }
    if (canReschedule) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonRescheduleBooking,
            'callback_data': '${MessageCopy.callbackBookingReschedulePrefix}$bookingId',
          },
        ],
      );
    }
    if (canCancel) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonCancelBooking,
            'callback_data': '${MessageCopy.callbackBookingCancelPrefix}$bookingId',
          },
        ],
      );
    }
    if (canRepeat) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonRepeatBooking,
            'callback_data': '${MessageCopy.callbackBookingRepeatPrefix}$bookingId',
          },
        ],
      );
    }
    if (canCompletePayment) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonCompletePayment,
            'callback_data': '${MessageCopy.callbackBookingContinuePayPrefix}$bookingId',
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> pendingPaymentReminderKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonSubmitPayment,
            'callback_data': '${MessageCopy.callbackPayBookingPrefix}$bookingId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> ctaBookInlineKeyboard({
    String buttonLabel = MessageCopy.buttonBookTraining,
  }) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': buttonLabel,
            'callback_data': MessageCopy.callbackCtaBook,
          },
        ],
      ],
    };
  }

  static Map<String, Object?> urlCtaInlineKeyboard({
    required String label,
    required String url,
  }) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': label,
            'url': url,
          },
        ],
      ],
    };
  }

  static Map<String, Object?> trainingFeedbackInlineKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonFeedbackGreat,
            'callback_data': '${MessageCopy.callbackFeedbackRatePrefix}$bookingId:great',
          },
          <String, String>{
            'text': MessageCopy.buttonFeedbackOk,
            'callback_data': '${MessageCopy.callbackFeedbackRatePrefix}$bookingId:ok',
          },
          <String, String>{
            'text': MessageCopy.buttonFeedbackWeak,
            'callback_data': '${MessageCopy.callbackFeedbackRatePrefix}$bookingId:weak',
          },
        ],
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonFeedbackSkip,
            'callback_data': '${MessageCopy.callbackFeedbackSkipPrefix}$bookingId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> adminBookingActionsInlineKeyboard(
    int bookingId, {
    required bool canRestore,
  }) {
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonEditBooking,
          'callback_data': '${MessageCopy.callbackAdminBookingEditPrefix}$bookingId',
        },
        <String, String>{
          'text': MessageCopy.buttonDeleteBooking,
          'callback_data': '${MessageCopy.callbackAdminBookingDeletePrefix}$bookingId',
        },
      ],
    ];
    if (canRestore) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonRestoreBooking,
            'callback_data': '${MessageCopy.callbackAdminBookingRestorePrefix}$bookingId',
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminBookingDeleteConfirmInlineKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonConfirmDeleteBooking,
            'callback_data': '${MessageCopy.callbackAdminBookingDeleteConfirmPrefix}$bookingId',
          },
          <String, String>{
            'text': MessageCopy.buttonCancelDeleteBooking,
            'callback_data': '${MessageCopy.callbackAdminBookingDeleteAbortPrefix}$bookingId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> adminClientNotificationPreferenceInlineKeyboard() {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonNotifyClientYes,
            'callback_data': MessageCopy.callbackAdminNotifyYes,
          },
          <String, String>{
            'text': MessageCopy.buttonNotifyClientNo,
            'callback_data': MessageCopy.callbackAdminNotifyNo,
          },
        ],
      ],
    };
  }

  static Map<String, Object?> paymentDecisionInlineKeyboard(
    int bookingId, {
    bool approvePartial = false,
  }) {
    final approveButton = approvePartial
        ? <String, String>{
            'text': '🟡 Подтвердить предоплату',
            'callback_data': '${MessageCopy.callbackApprovePartialPaymentPrefix}$bookingId',
          }
        : <String, String>{
            'text': '✅ Подтвердить оплату',
            'callback_data': '${MessageCopy.callbackApprovePaymentPrefix}$bookingId',
          };
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[approveButton],
      <Map<String, String>>[
        <String, String>{
          'text': '❌ Отклонить',
          'callback_data': '${MessageCopy.callbackRejectPaymentPrefix}$bookingId',
        },
      ],
    ];
    return <String, Object?>{
      'inline_keyboard': rows,
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

  static Map<String, Object?> nextPaymentInQueueInlineKeyboard({
    required ActivityCategory category,
    required int remaining,
  }) {
    final categoryKey = switch (category) {
      ActivityCategory.trainings => 'trainings',
      ActivityCategory.hikes => 'hikes',
      ActivityCategory.trails => 'trails',
    };
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': '➡️ Следующая заявка ($remaining)',
            'callback_data': '${MessageCopy.callbackNextPaymentInQueuePrefix}$categoryKey',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> subscriptionDecisionInlineKeyboard(int requestId) {
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{
          'text': '✅ Подтвердить абонемент',
          'callback_data': '${MessageCopy.callbackApproveSubscriptionPrefix}$requestId',
        },
      ],
      <Map<String, String>>[
        <String, String>{
          'text': '❌ Отклонить',
          'callback_data': '${MessageCopy.callbackRejectSubscriptionPrefix}$requestId',
        },
      ],
    ];
    return <String, Object?>{
      'inline_keyboard': rows,
    };
  }

  static Map<String, Object?> subscriptionCancelInlineKeyboard(int requestId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': '⛔️ Отменить абонемент',
            'callback_data': '${MessageCopy.callbackCancelSubscriptionPrefix}$requestId',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> adminSubscriptionsMenuKeyboard() {
    return adminSubscriptionFilterKeyboard();
  }

  static Map<String, Object?> adminSubscriptionFilterKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSubscriptionsFilterActive},
          <String, String>{'text': MessageCopy.buttonSubscriptionsFilterExpiring},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSubscriptionsFilterPending},
          <String, String>{'text': MessageCopy.buttonSubscriptionsFilterCancelled},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSubscriptionsSearch},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> subscriptionModerationReasonKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonReasonNotConfirmed},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonReasonWrongAmount},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonReasonDuplicate},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> subscriptionModerationCommentKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSkipComment},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
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

  static Map<String, Object?> myBookingSegmentKeyboard({
    required int currentCount,
    required int pastCount,
  }) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': '${MessageCopy.buttonCurrentBookings} ($currentCount)'},
          <String, String>{'text': '${MessageCopy.buttonPastBookings} ($pastCount)'},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> myBookingSelectionKeyboard(
    List<TrainingBooking> bookings, {
    required bool hasPreviousPage,
    required bool hasNextPage,
  }) {
    final rows = <List<Map<String, String>>>[];
    for (final booking in bookings) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': _bookingSelectionButtonText(booking)},
        ],
      );
    }
    if (hasPreviousPage || hasNextPage) {
      final pageButtons = <Map<String, String>>[];
      if (hasPreviousPage) {
        pageButtons.add(<String, String>{'text': MessageCopy.buttonBookingsPreviousPage});
      }
      if (hasNextPage) {
        pageButtons.add(<String, String>{'text': MessageCopy.buttonBookingsNextPage});
      }
      rows.add(pageButtons);
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonBack},
        <String, String>{'text': MessageCopy.buttonMainMenu},
      ],
    );
    return _replyKeyboard(rows);
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

  static Map<String, Object?> adminClientNotificationPreferenceKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonNotifyClientYes},
          <String, String>{'text': MessageCopy.buttonNotifyClientNo},
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
          <String, String>{'text': MessageCopy.buttonStatusPartialPaid},
          <String, String>{'text': MessageCopy.buttonStatusPaid},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonStatusPaymentRejected},
          <String, String>{'text': MessageCopy.buttonStatusFreeTraining},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> economicSummaryPeriodKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSummaryCurrentWeek},
          <String, String>{'text': MessageCopy.buttonSummaryPreviousWeek},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSummaryCurrentMonth},
          <String, String>{'text': MessageCopy.buttonSummaryPreviousMonth},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> broadcastTargetKeyboard({required bool hasGroup}) {
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonBroadcastToUsers,
          'callback_data': MessageCopy.callbackBroadcastToUsers,
        },
      ],
    ];
    if (hasGroup) {
      rows
        ..add(
          <Map<String, String>>[
            <String, String>{
              'text': MessageCopy.buttonBroadcastToUsersAndGroup,
              'callback_data': MessageCopy.callbackBroadcastToUsersAndGroup,
            },
          ],
        )
        ..add(
          <Map<String, String>>[
            <String, String>{
              'text': MessageCopy.buttonBroadcastToGroup,
              'callback_data': MessageCopy.callbackBroadcastToGroup,
            },
          ],
        );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonBroadcastCancel,
          'callback_data': MessageCopy.callbackBroadcastCancel,
        },
      ],
    );
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> onboardingContinueKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingContinue},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingQuizGoalKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizGoalForm},
          <String, String>{'text': MessageCopy.buttonQuizGoalEndurance},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizGoalOutdoor},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizGoalUnknown},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingSkipQuiz},
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingQuizExperienceKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizExpBeginner},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizExpReturning},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonQuizExpRegular},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingTrackKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonTrackOneOff},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonTrackOutdoor},
        ],
        // TODO(subscription): вернуть кнопку трека PRO.
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingMapCtaKeyboard({required bool outdoorTrack}) {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': outdoorTrack ? MessageCopy.buttonCategoryHikes : MessageCopy.buttonBookTraining,
          },
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
          <String, String>{'text': MessageCopy.buttonOnboardingNeedMoreTime},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingNudgeKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBookTraining},
          <String, String>{'text': MessageCopy.buttonTrainings},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedMoreTime},
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> onboardingActivationKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBookTraining},
          <String, String>{'text': MessageCopy.buttonProfile},
        ],
        // TODO(subscription): вернуть кнопку абонемента в activation CTA.
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonOnboardingNeedHelp},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> trainingFeedbackKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonFeedbackGreat},
          <String, String>{'text': MessageCopy.buttonFeedbackOk},
          <String, String>{'text': MessageCopy.buttonFeedbackWeak},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonFeedbackSkip},
        ],
      ],
    );
  }

  static Map<String, Object?> trainingFeedbackCommentKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonSkipComment},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static String _bookingSelectionButtonText(TrainingBooking booking) {
    final title = booking.trainingTitle;
    if (!booking.isManagedForOther) {
      return '🧾 #${booking.id} $title';
    }
    final participant = booking.participantDisplayLabel;
    final truncatedParticipant =
        participant.length > 24 ? '${participant.substring(0, 24)}…' : participant;
    return '🧾 #${booking.id} $truncatedParticipant · $title';
  }

  static Map<String, Object?> adminScheduleNavKeyboard() {
    return _replyKeyboard(
      <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
    );
  }

  static Map<String, Object?> adminScheduleRootInlineKeyboard() {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonCategoryTrainings,
            'callback_data': '${MessageCopy.callbackAdminSchedCatPrefix}t',
          },
          <String, String>{
            'text': MessageCopy.buttonCategoryHikes,
            'callback_data': '${MessageCopy.callbackAdminSchedCatPrefix}h',
          },
        ],
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonCategoryTrails,
            'callback_data': '${MessageCopy.callbackAdminSchedCatPrefix}r',
          },
        ],
      ],
    };
  }

  static Map<String, Object?> adminScheduleListInlineKeyboard({
    required String categoryCode,
    required List<String> itemLabels,
    required int page,
    required int pageSize,
    required int totalCount,
  }) {
    final rows = <List<Map<String, String>>>[];
    final start = page * pageSize;
    for (var i = 0; i < itemLabels.length; i++) {
      final index = start + i;
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': itemLabels[i],
            'callback_data': '${MessageCopy.callbackAdminSchedOpenPrefix}$categoryCode:$index',
          },
        ],
      );
    }
    if (totalCount > pageSize) {
      final nav = <Map<String, String>>[];
      if (page > 0) {
        nav.add(
          <String, String>{
            'text': '←',
            'callback_data': '${MessageCopy.callbackAdminSchedPagePrefix}$categoryCode:${page - 1}',
          },
        );
      }
      if (start + pageSize < totalCount) {
        nav.add(
          <String, String>{
            'text': '→',
            'callback_data': '${MessageCopy.callbackAdminSchedPagePrefix}$categoryCode:${page + 1}',
          },
        );
      }
      if (nav.isNotEmpty) {
        rows.add(nav);
      }
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleAdd,
          'callback_data': '${MessageCopy.callbackAdminSchedAddPrefix}$categoryCode',
        },
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleRefresh,
          'callback_data': '${MessageCopy.callbackAdminSchedRefPrefix}$categoryCode',
        },
      ],
    );
    rows.add(
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleInlineBack,
          'callback_data': MessageCopy.callbackAdminSchedRoot,
        },
      ],
    );
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminScheduleEventInlineKeyboard({
    required String categoryCode,
    required int index,
    bool showTrainingToggles = false,
    bool includeTrainers = false,
    bool promoRestricted = false,
    bool confirmingDelete = false,
  }) {
    if (confirmingDelete) {
      return <String, Object?>{
        'inline_keyboard': <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{
              'text': MessageCopy.buttonAdminScheduleDeleteConfirm,
              'callback_data': '${MessageCopy.callbackAdminSchedDelOkPrefix}$categoryCode:$index',
            },
            <String, String>{
              'text': MessageCopy.buttonAdminScheduleDeleteAbort,
              'callback_data': '${MessageCopy.callbackAdminSchedDelNoPrefix}$categoryCode:$index',
            },
          ],
        ],
      };
    }
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleEdit,
          'callback_data': '${MessageCopy.callbackAdminSchedEditPrefix}$categoryCode:$index',
        },
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleDeleteConfirm,
          'callback_data': '${MessageCopy.callbackAdminSchedDelPrefix}$categoryCode:$index',
        },
      ],
    ];
    if (showTrainingToggles) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': includeTrainers ? 'Тренеры в лимите: да' : 'Тренеры в лимите: нет',
            'callback_data': '${MessageCopy.callbackAdminSchedTogPrefix}it:$categoryCode:$index',
          },
        ],
      );
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': promoRestricted ? 'Без промокода: да' : 'Без промокода: нет',
            'callback_data': '${MessageCopy.callbackAdminSchedTogPrefix}pr:$categoryCode:$index',
          },
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleBackToList,
          'callback_data': '${MessageCopy.callbackAdminSchedCatPrefix}$categoryCode',
        },
      ],
    );
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminScheduleFieldsInlineKeyboard(List<(String, String)> fields) {
    final rows = <List<Map<String, String>>>[
      for (final field in fields)
        <Map<String, String>>[
          <String, String>{
            'text': field.$2,
            'callback_data': '${MessageCopy.callbackAdminSchedFieldPrefix}${field.$1}',
          },
        ],
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleBackToCard,
          'callback_data': MessageCopy.callbackAdminSchedBack,
        },
      ],
    ];
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminScheduleSkipInlineKeyboard({
    bool showSkip = true,
    List<String> extraLabels = const <String>[],
    List<String> extraCallbacks = const <String>[],
  }) {
    final rows = <List<Map<String, String>>>[];
    for (var i = 0; i < extraLabels.length && i < extraCallbacks.length; i++) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': extraLabels[i],
            'callback_data': extraCallbacks[i],
          },
        ],
      );
    }
    if (showSkip) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonOnboardingSkipQuiz,
            'callback_data': MessageCopy.callbackAdminSchedSkip,
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminScheduleBoolInlineKeyboard({required bool optional}) {
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleYes,
          'callback_data': '${MessageCopy.callbackAdminSchedBoolPrefix}1',
        },
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleNo,
          'callback_data': '${MessageCopy.callbackAdminSchedBoolPrefix}0',
        },
      ],
    ];
    if (optional) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonOnboardingSkipQuiz,
            'callback_data': MessageCopy.callbackAdminSchedSkip,
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminScheduleCoachInlineKeyboard(
    List<String> names, {
    required bool optional,
  }) {
    final rows = <List<Map<String, String>>>[
      for (var i = 0; i < names.length; i++)
        <Map<String, String>>[
          <String, String>{
            'text': names[i],
            'callback_data': '${MessageCopy.callbackAdminSchedCoachPrefix}$i',
          },
        ],
      <Map<String, String>>[
        <String, String>{
          'text': MessageCopy.buttonAdminScheduleCoachOther,
          'callback_data': '${MessageCopy.callbackAdminSchedCoachPrefix}x',
        },
      ],
    ];
    if (optional) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonOnboardingSkipQuiz,
            'callback_data': MessageCopy.callbackAdminSchedSkip,
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  static Map<String, Object?> adminSchedulePreviewInlineKeyboard() {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': MessageCopy.buttonAdminScheduleSave,
            'callback_data': MessageCopy.callbackAdminSchedSave,
          },
          <String, String>{
            'text': MessageCopy.buttonAdminScheduleCancelCreate,
            'callback_data': MessageCopy.callbackAdminSchedCancel,
          },
        ],
      ],
    };
  }
}
