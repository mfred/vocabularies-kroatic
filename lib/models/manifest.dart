import 'package:freezed_annotation/freezed_annotation.dart';

part 'manifest.freezed.dart';
part 'manifest.g.dart';

@freezed
abstract class Manifest with _$Manifest {
  const factory Manifest({
    required String schemaVersion,
    required String dataVersion,
    required String generatedAt,
    required String baseUrl,
    required ManifestLanguages languages,
    required List<ManifestLesson> lessons,
    // Aktuell ungenutzt — reserviert für einen künftigen Attributions-/Lizenz-
    // Screen (wird geparst, aber noch nirgends angezeigt).
    @JsonKey(name: 'globalLicenses') List<GlobalLicense>? globalLicenses,
  }) = _Manifest;

  factory Manifest.fromJson(Map<String, dynamic> json) =>
      _$ManifestFromJson(json);
}

@freezed
abstract class ManifestLanguages with _$ManifestLanguages {
  const factory ManifestLanguages({
    required String source,
    required String target,
  }) = _ManifestLanguages;

  factory ManifestLanguages.fromJson(Map<String, dynamic> json) =>
      _$ManifestLanguagesFromJson(json);
}

@freezed
abstract class ManifestLesson with _$ManifestLesson {
  const factory ManifestLesson({
    required String id,
    required String version,
    required LocalizedTitle title,
    LocalizedDescription? description,
    required int order,
    required int difficulty,
    required int wordCount,
    required int phraseCount,
    required int sentenceCount,
    @Default(<String>[]) List<String> prerequisites,
    @Default(<String>[]) List<String> tags,
    required String file,
    required String sha256,
    required int sizeBytes,
  }) = _ManifestLesson;

  factory ManifestLesson.fromJson(Map<String, dynamic> json) =>
      _$ManifestLessonFromJson(json);
}

@freezed
abstract class LocalizedTitle with _$LocalizedTitle {
  const factory LocalizedTitle({
    required String de,
    required String hr,
  }) = _LocalizedTitle;

  factory LocalizedTitle.fromJson(Map<String, dynamic> json) =>
      _$LocalizedTitleFromJson(json);
}

@freezed
abstract class LocalizedDescription with _$LocalizedDescription {
  const factory LocalizedDescription({
    required String de,
    String? hr,
  }) = _LocalizedDescription;

  factory LocalizedDescription.fromJson(Map<String, dynamic> json) =>
      _$LocalizedDescriptionFromJson(json);
}

@freezed
abstract class GlobalLicense with _$GlobalLicense {
  const factory GlobalLicense({
    required String id,
    required String name,
    required String url,
    required String license,
    required String licenseUrl,
  }) = _GlobalLicense;

  factory GlobalLicense.fromJson(Map<String, dynamic> json) =>
      _$GlobalLicenseFromJson(json);
}
