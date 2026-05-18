import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttResult {
  const SttResult({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Wraps `speech_to_text` for short, locale-targeted recognitions.
///
/// Recognition always runs **online** (`onDevice: false`). Offline
/// language packs for STT are not installable for many locales
/// (Croatian among them), and the Android `SpeechRecognizer` falls
/// back to Google's network recognizer just fine — no per-user
/// install needed.
class SttService {
  SttService();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool? _initialized;
  void Function(String)? _activeOnError;

  /// Drops the init-state cache so the next [initialize] re-queries
  /// the platform plugin.
  void invalidate() {
    _initialized = null;
  }

  Future<bool> initialize() async {
    if (_initialized == true) return true;
    if (_initialized == false) return false;
    try {
      _initialized = await _stt.initialize(
        onError: (SpeechRecognitionError err) {
          _activeOnError?.call(err.errorMsg);
        },
        onStatus: (_) {},
        debugLogging: false,
      );
    } catch (_) {
      _initialized = false;
    }
    return _initialized ?? false;
  }

  bool get isListening => _stt.isListening;

  Future<void> start({
    required String localeId,
    required void Function(SttResult) onResult,
    void Function(String)? onError,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!await initialize()) {
      if (onError != null) onError('not_available');
      return;
    }
    _activeOnError = onError;
    try {
      await _stt.listen(
        localeId: localeId.replaceAll('-', '_'),
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: stt.SpeechListenOptions(
          onDevice: false,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (SpeechRecognitionResult r) {
          onResult(SttResult(
            text: r.recognizedWords,
            isFinal: r.finalResult,
          ));
        },
      );
    } catch (e) {
      if (onError != null) onError(e.toString());
    }
  }

  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
    _activeOnError = null;
  }

  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
    _activeOnError = null;
  }
}
