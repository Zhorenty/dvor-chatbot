import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet with the app's surface, grab handle and keyboard-aware
/// padding. [builder] gets the sheet context.
Future<T?> showDvorSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
            child: builder(sheetContext),
          ),
        ),
      ),
    ),
  );
}

/// Big uppercase sheet/screen title with an optional muted line under it.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: context.text.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs),
          Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted)),
        ],
      ],
    );
  }
}

/// Uppercase eyebrow label above a group of controls.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.inkFaint,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class DvorTextField extends StatelessWidget {
  const DvorTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.error,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixText,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefixText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: 1,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      style: context.text.bodyLarge,
      cursorColor: c.accent,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        prefixText: prefixText,
        isDense: true,
        filled: true,
        fillColor: c.surfaceRaised,
        labelStyle: context.text.bodyMedium?.copyWith(color: c.inkMuted),
        hintStyle: context.text.bodyMedium?.copyWith(color: c.inkFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: border(c.stroke),
        focusedBorder: border(c.accent),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger),
      ),
    );
  }
}

/// Tappable row with an icon, title, muted subtitle and a trailing widget.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = tone ?? c.accent;
    return Pressable(
      onTap: busy ? null : onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.m),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.tile),
          border: Border.all(color: c.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Chips for picking one value.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final (value, label) in options)
          Pressable(
            onTap: () => onSelected(value),
            haptic: HapticKind.selection,
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: value == selected ? c.accent : c.surfaceRaised,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(color: value == selected ? c.accent : c.stroke),
              ),
              child: Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: value == selected ? c.onAccent : c.ink,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Runs a bot action with haptics and a toast of the bot's reply (or the
/// refusal). Returns the result, or null when the action failed.
Future<Map<String, Object?>?> runAction(
  BuildContext context,
  WidgetRef ref,
  Future<Map<String, Object?>> Function() action, {
  String? success,
}) async {
  final tg = ref.read(telegramProvider);
  try {
    final result = await action();
    tg.haptic(HapticKind.success);
    final message = success ?? result['message'] as String?;
    if (context.mounted && message != null && message.isNotEmpty) {
      showToast(context, message);
    }
    return result;
  } on ApiException catch (error) {
    tg.haptic(HapticKind.error);
    if (context.mounted) {
      showToast(context, error.message);
    }
    return null;
  }
}

/// Confirmation through Telegram's native popup, or a dialog in previews.
Future<bool> confirmAction(BuildContext context, WidgetRef ref, String message) async {
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
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Да')),
      ],
    ),
  );
  return result ?? false;
}
