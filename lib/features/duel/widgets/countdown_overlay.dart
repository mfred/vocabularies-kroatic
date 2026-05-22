import 'dart:async';

import 'package:flutter/material.dart';

/// Vollflächiger 3-2-1-GO-Countdown vor einer Runde. Blockt Touch-Eingaben
/// während der Anzeige und ruft [onFinished] nach dem "GO"-Flash auf.
class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  static const _stepDuration = Duration(milliseconds: 800);
  static const _goDuration = Duration(milliseconds: 500);

  int _step = 0; // 0..2 = 3..1, 3 = GO, 4 = done
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    final isGo = _step == 3;
    _timer = Timer(isGo ? _goDuration : _stepDuration, () {
      if (!mounted) return;
      if (_step >= 3) {
        _step = 4;
        widget.onFinished();
        return;
      }
      setState(() => _step += 1);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    switch (_step) {
      case 0:
        return '3';
      case 1:
        return '2';
      case 2:
        return '1';
      case 3:
        return 'LOS!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGo = _step == 3;
    final color = isGo
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey(_step),
            padding: EdgeInsets.symmetric(
              horizontal: isGo ? 32 : 48,
              vertical: isGo ? 18 : 28,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              _label,
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: isGo ? 64 : 96,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
