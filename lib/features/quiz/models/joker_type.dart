import 'package:flutter/material.dart';

enum JokerType {
  ipa('ipa', 'Lautschrift', Icons.record_voice_over_outlined, 5),
  fiftyFifty('50_50', '50/50', Icons.exposure_outlined, 15),
  picture('picture', 'Bild', Icons.image_outlined, 5);

  const JokerType(this.code, this.label, this.icon, this.cost);

  final String code;
  final String label;
  final IconData icon;
  final int cost;

  static JokerType? fromCode(String code) {
    for (final j in JokerType.values) {
      if (j.code == code) return j;
    }
    return null;
  }
}
