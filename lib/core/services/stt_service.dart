import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttResult {
  const SttResult({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Wraps `speech_to_text` for short, locale-targeted recognitions.
class SttService {
  SttService();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool? _initialized;

  /// Drops the init-state cache so the next [initialize] / [hasLocale]
  /// re-queries the platform plugin (e.g. after the user installed a
  /// missing locale via system settings).
  void invalidate() {
    _initialized = null;
  }

  Future<bool> initialize() async {
    if (_initialized == true) return true;
    if (_initialized == false) return false;
    try {
      _initialized = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
        debugLogging: false,
      );
    } catch (_) {
      _initialized = false;
    }
    return _initialized ?? false;
  }

  bool get isListening => _stt.isListening;

  Future<bool> hasLocale(String localeId) async {
    if (!await initialize()) return false;
    final locales = await _stt.locales();
    return locales.any((l) =>
        l.localeId.toLowerCase() == localeId.toLowerCase() ||
        l.localeId.toLowerCase().replaceAll('-', '_') ==
            localeId.toLowerCase().replaceAll('-', '_'));
  }

  Future<void> start({
    required String localeId,
    required void Function(SttResult) onResult,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!await initialize()) return;
    await _stt.listen(
      localeId: localeId.replaceAll('-', '_'),
      listenFor: listenFor,
      pauseFor: pauseFor,
      onResult: (SpeechRecognitionResult r) {
        onResult(SttResult(
          text: r.recognizedWords,
          isFinal: r.finalResult,
        ));
      },
    );
  }

  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }
}
