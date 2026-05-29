import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../models/lesson_data.dart';
import '../../models/manifest.dart';
import '../database/database.dart';

class SyncResult {
  SyncResult({
    required this.lessonsTotal,
    required this.lessonsUpdated,
    required this.itemsTotal,
    required this.fromCache,
    this.error,
  });

  final int lessonsTotal;
  final int lessonsUpdated;
  final int itemsTotal;
  final bool fromCache;
  final String? error;

  bool get success => error == null;
}

class ManifestSyncService {
  ManifestSyncService(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;
  final Logger _log = Logger();

  Future<SyncResult> syncAll() async {
    try {
      _log.i('Sync gestartet');
      final manifestResp = await _dio.get<dynamic>('manifest.json');
      final manifestJson = _asJsonMap(manifestResp.data);
      final manifest = Manifest.fromJson(manifestJson);
      _log.i('Manifest geladen: ${manifest.lessons.length} Lektionen');

      int updated = 0;
      for (final lesson in manifest.lessons) {
        final cached = await _db.getLessonCache(lesson.id);
        // Cache nur überspringen, wenn Version UND Inhalts-Hash passen.
        // Frühere Versionen prüften nur die Version — wurde der Lektions-
        // inhalt geändert (z. B. hr.ipa nachgepflegt), ohne die Version zu
        // erhöhen, blieben veraltete Items im Cache (Joker/IPA fehlten).
        if (cached != null &&
            cached.version == lesson.version &&
            cached.sha256.toLowerCase() == lesson.sha256.toLowerCase()) {
          _log.d('Lektion ${lesson.id} aktuell (v${lesson.version})');
          continue;
        }
        _log.i('Lade Lektion ${lesson.id} v${lesson.version}');
        // Body als rohe Bytes anfordern (ResponseType.bytes), damit Dio das
        // JSON NICHT decodiert. Der SHA-256 wird so über exakt die vom Server
        // gelieferten Bytes berechnet und stimmt unabhängig vom Content-Type
        // (text/plain vs. application/json) mit dem Manifest-Hash überein.
        // Früher re-serialisierte der Map-Pfad das JSON, was die Prüfung bei
        // application/json wertlos/fehlschlagend machte.
        final lessonResp = await _dio.get<List<int>>(
          lesson.file,
          options: Options(responseType: ResponseType.bytes),
        );
        final raw = lessonResp.data ?? const <int>[];
        final expectedSha = lesson.sha256.toLowerCase();
        final actualSha = sha256.convert(raw).toString();
        if (actualSha != expectedSha) {
          throw StateError(
            'SHA-256 mismatch in ${lesson.id}: '
            'expected $expectedSha, got $actualSha',
          );
        }
        final lessonData = LessonData.fromJson(
          jsonDecode(utf8.decode(raw)) as Map<String, dynamic>,
        );
        await _persistLesson(lesson, lessonData);
        updated++;
      }

      final total = await _db.countItems();
      _log.i('Sync abgeschlossen: $updated/${manifest.lessons.length} aktualisiert, $total Items insgesamt');

      return SyncResult(
        lessonsTotal: manifest.lessons.length,
        lessonsUpdated: updated,
        itemsTotal: total,
        fromCache: false,
      );
    } catch (e, st) {
      _log.w('Sync fehlgeschlagen: $e', error: e, stackTrace: st);
      final cachedLessons = await _db.allLessonsByOrder();
      final total = await _db.countItems();
      return SyncResult(
        lessonsTotal: cachedLessons.length,
        lessonsUpdated: 0,
        itemsTotal: total,
        fromCache: true,
        error: e.toString(),
      );
    }
  }

  Future<void> _persistLesson(
    ManifestLesson manifest,
    LessonData data,
  ) async {
    final itemRows = data.items
        .map(
          (item) => ItemsCompanion.insert(
            id: item.id,
            lessonId: manifest.id,
            type: item.type,
            stage: item.stage,
            difficulty: item.difficulty,
            deText: item.de.text,
            deIpa: Value(item.de.ipa),
            dePos: Value(item.de.pos),
            hrText: item.hr.text,
            hrIpa: Value(item.hr.ipa),
            hrPos: Value(item.hr.pos),
            alternativesHrJson: Value(
              item.alternatives == null
                  ? null
                  : jsonEncode(item.alternatives!.toJson()),
            ),
            tagsJson: Value(item.tags.isEmpty ? null : jsonEncode(item.tags)),
            notesDe: Value(item.notes?.de),
            requiresJson: Value(
              item.requiresIds.isEmpty ? null : jsonEncode(item.requiresIds),
            ),
            licenseJson: Value(
              item.license == null ? null : jsonEncode(item.license),
            ),
            lessonVersion: manifest.version,
          ),
        )
        .toList();

    await _db.replaceLessonItems(manifest.id, itemRows);

    await _db.upsertLessonCache(
      LessonsCacheCompanion.insert(
        lessonId: manifest.id,
        version: manifest.version,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
        sha256: manifest.sha256,
        orderIndex: manifest.order,
        titleDe: manifest.title.de,
        titleHr: manifest.title.hr,
        descriptionDe: Value(manifest.description?.de),
        difficulty: manifest.difficulty,
        wordCount: manifest.wordCount,
        phraseCount: manifest.phraseCount,
        sentenceCount: manifest.sentenceCount,
        prerequisitesJson: Value(
          manifest.prerequisites.isEmpty
              ? null
              : jsonEncode(manifest.prerequisites),
        ),
        tagsJson: Value(
          manifest.tags.isEmpty ? null : jsonEncode(manifest.tags),
        ),
      ),
    );
  }

  Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw StateError('Manifest response unexpected type: ${data.runtimeType}');
  }
}
