import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps [FlutterTts] for two languages (hr-HR, de-DE).
///
/// Lazy-init: the first call to [speak] triggers engine setup. Subsequent
/// calls reuse the same engine and only switch language as needed.
class TtsService {
  TtsService();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  final Map<String, bool> _availability = {};
  String? _currentLang;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<bool> isAvailable(String langTag) async {
    final cached = _availability[langTag];
    if (cached != null) return cached;
    await _ensureInit();
    bool available;
    try {
      final dynamic raw = await _tts.isLanguageAvailable(langTag);
      available = raw == true;
    } catch (_) {
      available = false;
    }
    _availability[langTag] = available;
    return available;
  }

  Future<void> speak(String text, String langTag) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    if (_currentLang != langTag) {
      await _tts.setLanguage(langTag);
      _currentLang = langTag;
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await _tts.stop();
  }
}
