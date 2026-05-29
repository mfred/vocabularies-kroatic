/// Kalendertag-Schlüssel `yyyymmdd` (z. B. 2026-05-29 → 20260529) für die
/// tagweise Entdoppelung/Gruppierung von Aktivität (Streak, Heatmap, Diagnose).
/// Reine, zeitzonen-lokale Funktion ohne Seiteneffekte.
///
/// Hinweis: Das daily-Quiz nutzt bewusst eine eigene `dailyDateKey`-Funktion
/// (`daily_quiz_builder.dart`) als stabilen Zufalls-Seed — diese darf NICHT
/// hierdurch ersetzt werden, sonst würden sich bestehende Tages-Quizze ändern.
int dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;
