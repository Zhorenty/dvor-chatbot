import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Telegram's native bottom button inside Telegram; a Flutter button in
/// local previews. Put it in `Scaffold.bottomNavigationBar`.
class TelegramMainButton extends ConsumerStatefulWidget {
  const TelegramMainButton({super.key, required this.state, required this.onTap});

  final MainButtonState? state;
  final VoidCallback onTap;

  @override
  ConsumerState<TelegramMainButton> createState() => _TelegramMainButtonState();
}

class _TelegramMainButtonState extends ConsumerState<TelegramMainButton> {
  late final TelegramPlatform _tg = ref.read(telegramProvider);
  Color? _color;
  Color? _textColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _color = context.colors.accent;
    _textColor = context.colors.onAccent;
    _sync();
  }

  @override
  void didUpdateWidget(covariant TelegramMainButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!_tg.isAvailable) {
      return;
    }
    final state = widget.state;
    _tg.setMainButton(
      state,
      onTap: state == null || !state.enabled || state.loading ? null : widget.onTap,
      color: _color!,
      textColor: _textColor!,
    );
  }

  @override
  void dispose() {
    if (_tg.isAvailable) {
      _tg.setMainButton(null, color: _color!, textColor: _textColor!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (_tg.isAvailable || state == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.m),
        child: PrimaryButton(
          label: state.text,
          loading: state.loading,
          onTap: state.enabled ? widget.onTap : null,
        ),
      ),
    );
  }
}

/// Shows Telegram's BackButton while mounted.
class TelegramBackButton extends ConsumerStatefulWidget {
  const TelegramBackButton({super.key, required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  ConsumerState<TelegramBackButton> createState() => _TelegramBackButtonState();
}

class _TelegramBackButtonState extends ConsumerState<TelegramBackButton> {
  late final TelegramPlatform _tg = ref.read(telegramProvider);

  @override
  void initState() {
    super.initState();
    _tg.setBackButton(visible: true, onTap: widget.onBack);
  }

  @override
  void dispose() {
    _tg.setBackButton(visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
