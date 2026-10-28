import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tap target that sinks slightly on press and fires a light haptic.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = HapticKind.light,
    this.scale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HapticKind? haptic;
  final double scale;
  final String? semanticLabel;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && _down != down) {
      setState(() => _down = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Semantics(
      button: onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: onTap == null
            ? null
            : () {
                final kind = widget.haptic;
                if (kind != null) {
                  ref.read(telegramProvider).haptic(kind);
                }
                onTap();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Rounded surface card with a hairline border.
class DvorCard extends StatelessWidget {
  const DvorCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.color,
    this.borderColor,
    this.radius = Radii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.stroke),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small rounded label, filled or outlined (outlined echoes the stories pill).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.color,
    this.filled = false,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final bool filled;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.inkMuted;
    final fg = filled ? onColor(tone) : tone;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: filled ? tone : tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.text.labelMedium?.copyWith(color: fg, fontSize: dense ? 11 : 12),
          ),
        ],
      ),
    );
  }

  static Color onColor(Color tone) =>
      tone.computeLuminance() > 0.45 ? const Color(0xFF0D0E0B) : Colors.white;
}

Color categoryColor(BuildContext context, EventCategory category) {
  final c = context.colors;
  return switch (category) {
    EventCategory.trainings => c.accent,
    EventCategory.hikes => c.hike,
    EventCategory.trails => c.trail,
  };
}

IconData categoryIcon(EventCategory category) => switch (category) {
  EventCategory.trainings => Icons.bolt_rounded,
  EventCategory.hikes => Icons.landscape_rounded,
  EventCategory.trails => Icons.terrain_rounded,
};

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 - 0.5;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end: Alignment(t * 2, 0),
              colors: [c.surfaceRaised, c.stroke.withValues(alpha: 0.2), c.surfaceRaised],
            ),
          ),
        );
      },
    );
  }
}

/// Centered message with an optional action, used for empty and error states.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.surfaceRaised, shape: BoxShape.circle),
            child: Icon(icon, color: c.accent, size: 28),
          ),
          const SizedBox(height: Space.l),
          Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
          if (body != null) ...[
            const SizedBox(height: Space.s),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.l),
            SecondaryButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: Icons.wifi_off_rounded,
      title: 'Не получилось загрузить',
      body: error is ApiException ? (error as ApiException).message : 'Попробуй ещё раз.',
      actionLabel: 'Обновить',
      onAction: onRetry,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null && !loading;
    return Pressable(
      onTap: enabled ? onTap : null,
      haptic: HapticKind.medium,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.accent : c.accent.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
              )
            : Text(
                label,
                style: context.text.labelLarge?.copyWith(color: c.onAccent, fontSize: 15),
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.ink;
    final child = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.stroke),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: tone), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
    return Pressable(onTap: onTap, child: child);
  }
}

/// DVOR wordmark from the club's stories.
class DvorLogo extends StatelessWidget {
  const DvorLogo({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo-dvor.png',
      height: height,
      color: context.colors.accent,
      colorBlendMode: BlendMode.srcIn,
      semanticLabel: 'DVOR',
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}
