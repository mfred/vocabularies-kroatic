import 'package:flutter/material.dart';

class QuizProgressBar extends StatelessWidget {
  const QuizProgressBar({
    super.key,
    required this.total,
    required this.currentIndex,
    required this.correctMask,
  });

  final int total;
  final int currentIndex;
  final List<bool?> correctMask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        Color color;
        if (i < correctMask.length && correctMask[i] != null) {
          color = correctMask[i] == true
              ? Colors.green.shade500
              : Colors.red.shade400;
        } else if (i == currentIndex) {
          color = theme.colorScheme.primary;
        } else {
          color = theme.colorScheme.outlineVariant;
        }
        return Container(
          width: 18,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
