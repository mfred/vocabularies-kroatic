import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import 'missing_language_dialog.dart';

class SpeakButton extends ConsumerStatefulWidget {
  const SpeakButton({
    super.key,
    required this.text,
    required this.langTag,
    this.size = 22,
    this.color,
    this.tooltip,
  });

  final String text;
  final String langTag;
  final double size;
  final Color? color;
  final String? tooltip;

  @override
  ConsumerState<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<SpeakButton> {
  bool? _available;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _resolveAvailability();
  }

  Future<void> _resolveAvailability() async {
    final tts = ref.read(ttsServiceProvider);
    final ok = await tts.isAvailable(widget.langTag);
    if (!mounted) return;
    setState(() => _available = ok);
  }

  Future<void> _onPressed() async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await ref
          .read(ttsServiceProvider)
          .speak(widget.text, widget.langTag);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _onPressedWhileDisabled() async {
    await showMissingLanguageDialog(
      context,
      LanguageFeature.tts,
      widget.langTag,
    );
    if (!mounted) return;
    ref.read(ttsServiceProvider).invalidate(widget.langTag);
    setState(() => _available = null);
    await _resolveAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = _available == false;
    final iconColor = disabled
        ? theme.colorScheme.outline
        : (widget.color ?? theme.colorScheme.primary);
    return IconButton(
      tooltip: widget.tooltip ??
          (disabled
              ? 'Sprache (${widget.langTag}) nicht installiert — tippen für Hilfe'
              : 'Aussprechen'),
      iconSize: widget.size,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      onPressed: disabled ? _onPressedWhileDisabled : _onPressed,
      icon: Icon(
        disabled
            ? Icons.volume_off_outlined
            : (_speaking ? Icons.graphic_eq : Icons.volume_up_outlined),
        color: iconColor,
      ),
    );
  }
}
