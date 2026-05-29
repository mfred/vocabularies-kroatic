import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';

class QuizMicInput extends ConsumerStatefulWidget {
  const QuizMicInput({
    super.key,
    required this.langTag,
    required this.locked,
    required this.lastInput,
    required this.onSubmit,
  });

  final String langTag;
  final bool locked;
  final String? lastInput;
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<QuizMicInput> createState() => _QuizMicInputState();
}

class _QuizMicInputState extends ConsumerState<QuizMicInput> {
  bool _listening = false;
  String _liveTranscript = '';
  String? _error;

  @override
  void dispose() {
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
      if (_liveTranscript.trim().isNotEmpty) {
        widget.onSubmit(_liveTranscript.trim());
      }
      return;
    }
    if (!await svc.initialize()) {
      setState(() => _error = 'Spracherkennung nicht verfügbar.');
      return;
    }
    setState(() {
      _listening = true;
      _liveTranscript = '';
      _error = null;
    });
    await svc.start(
      localeId: widget.langTag,
      onResult: (r) {
        if (!mounted) return;
        setState(() => _liveTranscript = r.text);
        if (r.isFinal) {
          setState(() => _listening = false);
          if (r.text.trim().isNotEmpty) {
            widget.onSubmit(r.text.trim());
          }
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _listening
                  ? scheme.primary
                  : scheme.outlineVariant,
              width: _listening ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: disabled ? null : _toggle,
                iconSize: 36,
                color:
                    _listening ? scheme.primary : scheme.onSurfaceVariant,
                icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
                tooltip:
                    _listening ? 'Aufnahme stoppen' : 'Aufnahme starten',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  shownText.isEmpty
                      ? (_listening
                          ? 'Bitte sprechen …'
                          : 'Tippe auf das Mikro und sprich die Antwort')
                      : shownText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: shownText.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontStyle: shownText.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
