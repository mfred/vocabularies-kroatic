import 'package:flutter/material.dart';

import '../../../core/database/database.dart';

class LessonFilterBar extends StatelessWidget {
  const LessonFilterBar({
    super.key,
    required this.lessons,
    required this.selectedLessonId,
    required this.onSelected,
  });

  final List<LessonsCacheData> lessons;
  final String? selectedLessonId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: FilterChip(
              label: const Text('Alle'),
              selected: selectedLessonId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final l in lessons)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: FilterChip(
                label: Text(l.titleDe),
                selected: selectedLessonId == l.lessonId,
                onSelected: (_) => onSelected(l.lessonId),
              ),
            ),
        ],
      ),
    );
  }
}
