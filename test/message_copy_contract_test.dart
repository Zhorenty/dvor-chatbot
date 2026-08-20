import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/keyboards/telegram_keyboards.dart';
import 'package:test/test.dart';

void main() {
  group('MessageCopy contract with TelegramKeyboards', () {
    test('reply keyboards use copy constants for navigation and actions', () {
      final allTexts = <String>{
        ..._replyTexts(TelegramKeyboards.privateMenuKeyboard(isAdmin: true)),
        ..._replyTexts(TelegramKeyboards.privateMenuKeyboard(isAdmin: false)),
        ..._replyTexts(
          TelegramKeyboards.privateMenuKeyboard(
            isAdmin: false,
            showReturnToAdminMenu: true,
          ),
        ),
        ..._replyTexts(TelegramKeyboards.adminToolsKeyboard()),
        ..._replyTexts(TelegramKeyboards.adminAnalyticsKeyboard()),
        ..._replyTexts(TelegramKeyboards.adminSubscriptionFilterKeyboard()),
        ..._replyTexts(TelegramKeyboards.categorySelectionKeyboard()),
        ..._replyTexts(TelegramKeyboards.scheduleCategoryActionsKeyboard()),
        ..._replyTexts(
          TelegramKeyboards.paymentConfirmationKeyboard(
            showStarterBonus: true,
            showCancelBooking: true,
            showOutdoorPaymentTypeChoice: true,
          ),
        ),
        ..._replyTexts(
          TelegramKeyboards.paymentConfirmationKeyboard(
            showStarterBonus: true,
            showCancelBooking: true,
            showOutdoorPaymentTypeChoice: false,
          ),
        ),
        ..._replyTexts(
          TelegramKeyboards.bookingActionsKeyboard(
            canReschedule: true,
            canCancel: true,
            canRepeat: true,
            canContinuePayment: true,
          ),
        ),
        ..._replyTexts(TelegramKeyboards.bookingCancelConfirmKeyboard()),
        ..._replyTexts(TelegramKeyboards.profileActionsKeyboard()),
      };

      expect(allTexts, contains(MessageCopy.buttonBack));
      expect(allTexts, contains(MessageCopy.buttonMainMenu));
      expect(allTexts, contains(MessageCopy.buttonAdminTools));
      expect(allTexts, isNot(contains(MessageCopy.buttonAdminAnalytics)));
      expect(allTexts, isNot(contains(MessageCopy.buttonNoblesList)));
      expect(allTexts, isNot(contains(MessageCopy.buttonAdminRecentActions)));
      expect(allTexts, contains(MessageCopy.buttonFunnelAnalytics));
      expect(allTexts, contains(MessageCopy.buttonFeedbackAnalytics));
      expect(allTexts, contains(MessageCopy.buttonBookingAnalytics));
      expect(allTexts, contains(MessageCopy.buttonLoyaltyAnalytics));
      expect(allTexts, contains(MessageCopy.buttonSubscriptionAnalytics));
      expect(allTexts, contains(MessageCopy.buttonClientMenu));
      expect(allTexts, contains(MessageCopy.buttonAdminMenu));
      expect(allTexts, contains(MessageCopy.buttonSubscriptionsSearch));
      expect(allTexts, contains(MessageCopy.buttonSubmitPayment));
      expect(allTexts, contains(MessageCopy.buttonPayFully));
      expect(allTexts, contains(MessageCopy.buttonPayPartially));
      expect(allTexts, contains(MessageCopy.buttonUseStarterBonus));
      expect(allTexts, contains(MessageCopy.buttonCancelBooking));
      expect(allTexts, contains(MessageCopy.buttonContinuePayment));
      expect(allTexts, contains(MessageCopy.buttonConfirmCancelBooking));
      expect(allTexts, contains(MessageCopy.buttonAdminSchedule));
      expect(allTexts, contains(MessageCopy.buttonManageBookings));
      expect(allTexts, contains(MessageCopy.buttonBookTraining));
      expect(allTexts, contains(MessageCopy.buttonBookFriend));
      expect(allTexts, contains(MessageCopy.buttonReferralProgram));
      // TODO(subscription): вернуть expect на MessageCopy.buttonSubscription после включения кнопки.
      expect(allTexts, isNot(contains(MessageCopy.buttonSubscription)));
    });

    test('inline callbacks use copy callback prefixes', () {
      final decision = TelegramKeyboards.paymentDecisionInlineKeyboard(42, approvePartial: true);
      final openQueue = TelegramKeyboards.openPaymentsQueueInlineKeyboard();
      final reminder = TelegramKeyboards.pendingPaymentReminderKeyboard(777);
      final paymentCard = TelegramKeyboards.paymentCardInlineKeyboard(
        12,
        showStarterBonus: true,
        showCancelBooking: true,
        showOutdoorPaymentTypeChoice: true,
        showPromoCodeEntry: true,
      );
      final bookingActions = TelegramKeyboards.bookingActionsInlineKeyboard(
        bookingId: 34,
        canReschedule: true,
        canCancel: true,
        canRepeat: true,
        canContinuePayment: true,
      );
      final cancelConfirm = TelegramKeyboards.bookingCancelConfirmInlineKeyboard(56);
      final feedback = TelegramKeyboards.trainingFeedbackInlineKeyboard(78);
      final ctaBook = TelegramKeyboards.ctaBookInlineKeyboard();
      final adminActions =
          TelegramKeyboards.adminBookingActionsInlineKeyboard(90, canRestore: true);
      final adminDelete = TelegramKeyboards.adminBookingDeleteConfirmInlineKeyboard(91);
      final adminNotify = TelegramKeyboards.adminClientNotificationPreferenceInlineKeyboard();
      final callbacks = <String>{
        ..._inlineCallbacks(decision),
        ..._inlineCallbacks(openQueue),
        ..._inlineCallbacks(reminder),
        ..._inlineCallbacks(paymentCard),
        ..._inlineCallbacks(bookingActions),
        ..._inlineCallbacks(cancelConfirm),
        ..._inlineCallbacks(feedback),
        ..._inlineCallbacks(ctaBook),
        ..._inlineCallbacks(adminActions),
        ..._inlineCallbacks(adminDelete),
        ..._inlineCallbacks(adminNotify),
      };

      expect(
        callbacks.any((item) => item.startsWith(MessageCopy.callbackApprovePartialPaymentPrefix)),
        isTrue,
      );
      expect(
        callbacks.any((item) => item.startsWith(MessageCopy.callbackRejectPaymentPrefix)),
        isTrue,
      );
      expect(callbacks, contains(MessageCopy.callbackOpenPaymentsQueue));
      expect(callbacks, contains('${MessageCopy.callbackPayBookingPrefix}777'));
      expect(callbacks, contains('${MessageCopy.callbackPayFullPrefix}12'));
      expect(callbacks, contains('${MessageCopy.callbackPayPartialPrefix}12'));
      expect(callbacks, contains('${MessageCopy.callbackUseBonusPrefix}12'));
      expect(callbacks, contains('${MessageCopy.callbackEnterPromoPrefix}12'));
      expect(callbacks, contains('${MessageCopy.callbackBookingCancelPrefix}12'));
      expect(callbacks, contains('${MessageCopy.callbackBookingReschedulePrefix}34'));
      expect(callbacks, contains('${MessageCopy.callbackBookingRepeatPrefix}34'));
      expect(callbacks, contains('${MessageCopy.callbackBookingContinuePayPrefix}34'));
      expect(callbacks, contains('${MessageCopy.callbackBookingCancelConfirmPrefix}56'));
      expect(callbacks, contains('${MessageCopy.callbackBookingCancelKeepPrefix}56'));
      expect(callbacks, contains('${MessageCopy.callbackFeedbackSkipPrefix}78'));
      expect(
          callbacks.any((item) => item.startsWith('${MessageCopy.callbackFeedbackRatePrefix}78:')),
          isTrue);
      expect(callbacks, contains(MessageCopy.callbackCtaBook));
      expect(callbacks, contains('${MessageCopy.callbackAdminBookingEditPrefix}90'));
      expect(callbacks, contains('${MessageCopy.callbackAdminBookingDeletePrefix}90'));
      expect(callbacks, contains('${MessageCopy.callbackAdminBookingDeleteConfirmPrefix}91'));
      expect(callbacks, contains('${MessageCopy.callbackAdminBookingDeleteAbortPrefix}91'));
      expect(callbacks, contains(MessageCopy.callbackAdminNotifyYes));
      expect(callbacks, contains(MessageCopy.callbackAdminNotifyNo));
    });
  });
}

Set<String> _replyTexts(Map<String, Object?> keyboard) {
  final rowsRaw = keyboard['keyboard'];
  if (rowsRaw is! List) {
    return const <String>{};
  }
  final result = <String>{};
  for (final row in rowsRaw) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['text'] is String) {
        result.add(button['text']! as String);
      }
    }
  }
  return result;
}

Set<String> _inlineCallbacks(Map<String, Object?> keyboard) {
  final rowsRaw = keyboard['inline_keyboard'];
  if (rowsRaw is! List) {
    return const <String>{};
  }
  final result = <String>{};
  for (final row in rowsRaw) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['callback_data'] is String) {
        result.add(button['callback_data']! as String);
      }
    }
  }
  return result;
}
