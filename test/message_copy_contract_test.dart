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
      // TODO(dvor-x-frank): вернуть expect на MessageCopy.buttonDvorXFrank после включения кнопки.
      expect(allTexts, isNot(contains(MessageCopy.buttonTrainings)));
      expect(allTexts, contains(MessageCopy.buttonBookTraining));
      expect(allTexts, contains(MessageCopy.buttonReferralProgram));
    });

    test('inline callbacks use copy callback prefixes', () {
      final decision = TelegramKeyboards.paymentDecisionInlineKeyboard(42, approvePartial: true);
      final openQueue = TelegramKeyboards.openPaymentsQueueInlineKeyboard();
      final callbacks = <String>{
        ..._inlineCallbacks(decision),
        ..._inlineCallbacks(openQueue),
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
