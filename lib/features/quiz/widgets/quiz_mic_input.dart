import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../services/answer_evaluator.dart';

class QuizMicInput extends ConsumerStatefulWidget {
  const QuizMicInput({
    super.key,
    required this.langTag,
    required this.locked,
    required this.lastInput,
    required this.expectedAnswer,
    required this.onSubmit,
  });

  final String langTag;
  final bool locked;
  final String? lastInput;

  /// Zielwort, gegen das jeder Sprechversuch lokal (gleiche Logik wie der
  /// Controller: tolerant + fuzzy) bewertet wird, um Wiederholversuche zu
  /// erlauben, ohne die Antwort vorzeitig zu werten.
  final String expectedAnswer;

  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<QuizMicInput> createState() => _QuizMicInputState();
}

class _QuizMicInputState extends ConsumerState<QuizMicInput>
    with SingleTickerProviderStateMixin {
  /// Nach so vielen falsch ausgesprochenen Versuchen gilt die Antwort als
  /// falsch (Iteration 69).
  static const int _maxAttempts = 3;

  bool _listening = false;
  String _liveTranscript = '';
  String? _error;

  /// Zahl der bisher falsch ausgesprochenen Versuche dieser Frage.
  int _wrongAttempts = 0;

  /// Verhindert, dass derselbe Sprech-Durchgang doppelt gewertet wird
  /// (manuelles Stop + finales Ergebnis können beide feuern).
  bool _resultHandled = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    // Laufende Spracherkennung beim Verlassen hart abbrechen: cancel() statt
    // stop() — kein onSubmit-Seiteneffekt beim Verlassen. Ohne dispose() bliebe
    // die einzige SttService-Session (kein autoDispose) bis zum listenFor/
    // pauseFor-Timeout aktiv und belegte das Mikrofon weiter. cancel() ist
    // intern gegen „nicht aktiv" abgesichert.
    ref.read(sttServiceProvider).cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final svc = ref.read(sttServiceProvider);
    if (_listening) {
      await svc.stop();
      setState(() => _listening = false);
      _handleSpokenResult(_liveTranscript);
      return;
    }
    if (!await svc.initialize()) {
      setState(() => _error = 'Spracherkennung nicht verfügbar.');
      return;
    }
    setState(() {
      _listening = true;
      _liveTranscript = '';
      _resultHandled = false;
      _error = null;
    });
    await svc.start(
      localeId: widget.langTag,
      onResult: (r) {
        if (!mounted) return;
        setState(() => _liveTranscript = r.text);
        if (r.isFinal) {
          setState(() => _listening = false);
          _handleSpokenResult(r.text);
        }
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _error = 'Spracherkennung fehlgeschlagen — '
              'Spracherkennung läuft online, '
              'bitte Internetverbindung prüfen.';
        });
      },
    );
  }

  /// Wertet einen abgeschlossenen Sprech-Durchgang aus. Bei korrekter
  /// Aussprache wird sofort gewertet; ein Fehlversuch wird nur dann endgültig
  /// als falsch gewertet, wenn das [_maxAttempts]-Limit erreicht ist —
  /// andernfalls darf der Nutzer erneut sprechen.
  void _handleSpokenResult(String raw) {
    if (_resultHandled) return;
    final text = raw.trim();
    if (text.isEmpty) return; // Nichts erkannt → kein Versuch verbraucht.
    _resultHandled = true;

    final eval = const AnswerEvaluator().evaluate(
      text,
      widget.expectedAnswer,
      tolerant: true,
      fuzzy: true,
    );
    if (eval.isCorrect) {
      widget.onSubmit(text);
      return;
    }

    final attempts = _wrongAttempts + 1;
    if (attempts >= _maxAttempts) {
      // Drei Fehlversuche → endgültig falsch werten (Controller sperrt,
      // korrekte Lösung bleibt bis „Weiter" stehen).
      widget.onSubmit(text);
      return;
    }
    setState(() => _wrongAttempts = attempts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = widget.locked;
    final showLive = _listening && _liveTranscript.isNotEmpty;
    final shownText = widget.locked
        ? (widget.lastInput ?? '')
        : (showLive ? _liveTranscript : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _MicButton(
          listening: _listening,
          disabled: disabled,
          pulse: _pulse,
          onTap: disabled ? null : _toggle,
        )),
        const SizedBox(height: 14),
        Text(
          shownText.isEmpty
              ? (_listening
                  ? 'Bitte sprechen …'
                  : 'Tippe auf das Mikrofon und sprich die Antwort')
              : shownText,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: shownText.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
            fontStyle: shownText.isEmpty ? FontStyle.italic : FontStyle.normal,
            fontWeight:
                shownText.isEmpty ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        if (!widget.locked && _wrongAttempts > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Noch nicht richtig — Versuch ${_wrongAttempts + 1} von $_maxAttempts. '
            'Tippe und sprich nochmal.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// Großer, runder Mikrofon-Knopf — bewusst präsent als zentrales Bedien-
/// element des Sprech-Quiz. Pulsiert beim Zuhören.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.disabled,
    required this.pulse,
    required this.onTap,
  });

  final bool listening;
  final bool disabled;
  final Animation<double> pulse;
  final VoidCallback? onTap;

  static const double _diameter = 116;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg = disabled
        ? scheme.surfaceContainerHighest
        : (listening ? scheme.primary : scheme.primaryContainer);
    final Color fg = disabled
        ? scheme.onSurfaceVariant
        : (listening ? scheme.onPrimary : scheme.onPrimaryContainer);

    return SizedBox(
      width: _diameter + 32,
      height: _diameter + 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsierender Ring nur beim Zuhören.
          if (listening)
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                final t = pulse.value;
                return Container(
                  width: _diameter + 32 * t,
                  height: _diameter + 32 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.18 * (1 - t)),
                  ),
                );
              },
            ),
          Material(
            color: bg,
            shape: const CircleBorder(),
            elevation: disabled ? 0 : 3,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _diameter,
                height: _diameter,
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 56,
                  color: fg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
