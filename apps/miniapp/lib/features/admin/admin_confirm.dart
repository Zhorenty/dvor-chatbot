import 'package:dvor_miniapp/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Telegram confirm with a Flutter fallback outside Telegram.
Future<bool> confirmAdminAction(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required String confirmLabel,
}) async {
  final tg = ref.read(telegramProvider);
  if (tg.isAvailable) {
    return tg.confirm(message);
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Нет')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}
