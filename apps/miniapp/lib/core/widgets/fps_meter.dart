import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Frame-rate readout for measuring on real devices inside Telegram
/// (`?startapp=fps`). Flutter web has no PerformanceOverlay, so it counts
/// vsync timestamps of frames the app actually produced: idle screens show
/// "idle", scrolling shows fps, the worst frame and frames over 25 ms.
class FpsMeter extends StatefulWidget {
  const FpsMeter({super.key, required this.child});

  final Widget child;

  @override
  State<FpsMeter> createState() => _FpsMeterState();
}

class _FpsMeterState extends State<FpsMeter> {
  static const Duration _gap = Duration(milliseconds: 250);
  static const Duration _dropped = Duration(milliseconds: 25);

  final ValueNotifier<String> _label = ValueNotifier('idle');
  final List<Duration> _intervals = <Duration>[];
  Duration? _last;
  Timer? _timer;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    // Persistent callbacks cannot be removed; the flag stops work after dispose.
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _publish());
  }

  void _onFrame(Duration timestamp) {
    if (!_alive) {
      return;
    }
    final last = _last;
    if (last != null) {
      final interval = timestamp - last;
      // Longer gaps mean the app was idle, not slow.
      if (interval > Duration.zero && interval < _gap) {
        _intervals.add(interval);
      }
    }
    _last = timestamp;
  }

  void _publish() {
    if (_intervals.length < 5) {
      _intervals.clear();
      _label.value = 'idle';
      return;
    }
    final totalUs = _intervals.fold<int>(0, (sum, i) => sum + i.inMicroseconds);
    final fps = _intervals.length * 1e6 / totalUs;
    final worst = _intervals.reduce((a, b) => a > b ? a : b);
    final drops = _intervals.where((i) => i > _dropped).length;
    _label.value = '${fps.round()} fps · max ${worst.inMilliseconds} ms · drops $drops';
    _intervals.clear();
  }

  @override
  void dispose() {
    _alive = false;
    _timer?.cancel();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<String>(
                  valueListenable: _label,
                  builder: (context, value, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFFADB838),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
