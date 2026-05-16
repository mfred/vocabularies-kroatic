import 'package:freezed_annotation/freezed_annotation.dart';

part 'lesson_data.freezed.dart';
part 'lesson_data.g.dart';

@freezed
abstract class LessonData with _$LessonData {
  const factory LessonData({
    required String schemaVersion,
    required String lessonId,
    required String version,
    required LessonTitle title,
    LessonDescription? description,
    required List<LessonStage> stages,
    required List<LessonItem> items,
  }) = _LessonData;

  factory LessonData.fromJson(Map<String, dynamic> json) =>
      _$LessonDataFromJson(json);
}

@freezed
abstract class LessonTitle with _$LessonTitle {
  const factory LessonTitle({
    required String de,
    required String hr,
  }) = _LessonTitle;

  factory LessonTitle.fromJson(Map<String, dynamic> json) =>
      _$LessonTitleFromJson(json);
}

@freezed
abstract class LessonDescription with _$LessonDescription {
  const factory LessonDescription({
    required String de,
    String? hr,
  }) = _LessonDescription;

  factory LessonDescription.fromJson(Map<String, dynamic> json) =>
      _$LessonDescriptionFromJson(json);
}

@freezed
abstract class LessonStage with _$LessonStage {
  const factory LessonStage({
    required String id,
    required String type,
    required StageLabel label,
  }) = _LessonStage;

  factory LessonStage.fromJson(Map<String, dynamic> json) =>
      _$LessonStageFromJson(json);
}

@freezed
abstract class StageLabel with _$StageLabel {
  const factory StageLabel({
    required String de,
    String? hr,
  }) = _StageLabel;

  factory StageLabel.fromJson(Map<String, dynamic> json) =>
      _$StageLabelFromJson(json);
}

@freezed
abstract class LessonItem with _$LessonItem {
  const factory LessonItem({
    required String id,
    required String type,
    required String stage,
    required int difficulty,
    required ItemLanguage de,
    required ItemLanguage hr,
    ItemAlternatives? alternatives,
    @Default(<String>[]) List<String> tags,
    ItemNotes? notes,
    @JsonKey(name: 'requires')
    @Default(<String>[]) List<String> requiresIds,
    @Default(<String>[]) List<String> wordRefs,
    Map<String, dynamic>? license,
  }) = _LessonItem;

  factory LessonItem.fromJson(Map<String, dynamic> json) =>
      _$LessonItemFromJson(json);
}

@freezed
abstract class ItemLanguage with _$ItemLanguage {
  const factory ItemLanguage({
    required String text,
    String? ipa,
    String? pos,
    String? audioHint,
  }) = _ItemLanguage;

  factory ItemLanguage.fromJson(Map<String, dynamic> json) =>
      _$ItemLanguageFromJson(json);
}

@freezed
abstract class ItemAlternatives with _$ItemAlternatives {
  const factory ItemAlternatives({
    @Default(<String>[]) List<String> hr,
    @Default(<String>[]) List<String> de,
  }) = _ItemAlternatives;

  factory ItemAlternatives.fromJson(Map<String, dynamic> json) =>
      _$ItemAlternativesFromJson(json);
}

@freezed
abstract class ItemNotes with _$ItemNotes {
  const factory ItemNotes({
    String? de,
    String? hr,
  }) = _ItemNotes;

  factory ItemNotes.fromJson(Map<String, dynamic> json) =>
      _$ItemNotesFromJson(json);
}
