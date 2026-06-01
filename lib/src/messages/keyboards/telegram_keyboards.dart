import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';

final class TelegramKeyboards {
  const TelegramKeyboards._();

  static Map<String, Object?> privateMenuKeyboard({required bool isAdmin}) {
    if (isAdmin) {
      return <String, Object?>{
        'keyboard': <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonRefreshSchedule},
            <String, String>{'text': MessageCopy.buttonPaymentsQueue},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageCopy.buttonParticipantsList},
            <String, String>{'text': MessageCopy.buttonNoblesList},
          ],
        ],
        'resize_keyboard': true,
        'one_time_keyboard': false,
      };
    }

    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonTrainings},
        <String, String>{'text': MessageCopy.buttonBookTraining},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonMyBookings},
      ],
      <Map<String, String>>[
        <String, String>{'text': MessageCopy.buttonHelp},
      ],
    ];
    return <String, Object?>{
      'keyboard': rows,
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
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
    return <String, Object?>{
      'keyboard': rows,
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  static Map<String, Object?> categorySelectionKeyboard() {
    return <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonCategoryTrainings},
          <String, String>{'text': MessageCopy.buttonCategoryHikes},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonCategoryTrails},
        ],
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  static Map<String, Object?> paymentConfirmationKeyboard() {
    return <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': MessageCopy.buttonBack},
          <String, String>{'text': MessageCopy.buttonMainMenu},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
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
}
