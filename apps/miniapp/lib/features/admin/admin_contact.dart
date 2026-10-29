import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a member's Telegram profile. With @username it opens directly;
/// without one the bot sends the admin a `tg://user?id` link (the only way
/// Telegram allows) and the app switches to that chat.
Future<void> openMemberProfile(
  BuildContext context,
  WidgetRef ref, {
  int? userId,
  String? username,
  String? about,
}) async {
  final name = username?.replaceFirst('@', '').trim();
  if (name != null && name.isNotEmpty) {
    ref.read(telegramProvider).openTelegramLink('https://t.me/$name');
    return;
  }
  if (userId == null || userId <= 0) {
    return;
  }
  final result = await runAction(
    context,
    ref,
    () => ref.read(repositoryProvider).rpc('admin.contact', {'userId': userId, 'context': ?about}),
  );
  if (result != null) {
    openBotChat(ref);
  }
}
