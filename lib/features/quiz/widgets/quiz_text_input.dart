import 'package:flutter/material.dart';

import '../../../core/widgets/speak_button.dart';

class QuizTextInput extends StatefulWidget {
  const QuizTextInput({
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
  State<QuizTextInput> createState() => _QuizTextInputState();
}

class _QuizTextInputState extends State<QuizTextInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant QuizTextInput old) {
    super.didUpdateWidget(old);
    if (!widget.locked && old.locked) {
      _controller.clear();
      _focus.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.locked && mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shownText = widget.locked ? (widget.lastInput ?? '') : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: !widget.locked,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.locked ? null : 'Deine Antwort …',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: widget.locked
                ? null
                : IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submit,
                    tooltip: 'Antwort abschicken',
                  ),
          ),
        ),
        if (widget.locked && shownText != null && shownText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Eingabe: $shownText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SpeakButton(text: shownText, langTag: widget.langTag),
              ],
            ),
          ),
      ],
    );
  }
}
