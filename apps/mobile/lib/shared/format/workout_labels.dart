/// The two formats only a workout needs: a pace, and a signed drift.
///
/// Both take a nullable and return a nullable, so a call site hands the server's
/// field straight in and [StatBlock] renders nothing for a null. That is
/// deliberate: a formatter that turned an absent pace into `'—'` would be this
/// app inventing a placeholder, and the reason for the absence would then have
/// nowhere to be — `refused_figures.dart` is where it goes instead.
library;

/// `7.14` → `7:08`. Minutes per kilometre as a clock, the way a runner reads it.
///
/// **The seconds are the server's number rounded, not recomputed.**
/// `read/workout.py` publishes `pace_min_per_km` already rounded to two decimal
/// places, and deriving a pace here from distance and duration instead would be
/// a second definition of the same quantity, free to disagree with the first by
/// a second per kilometre. `CLAUDE.md`'s one-definition rule is exactly this.
String? paceLabel(double? minPerKm) {
  if (minPerKm == null || !minPerKm.isFinite || minPerKm < 0) {
    return null;
  }
  final minutes = minPerKm.floor();
  final seconds = ((minPerKm - minutes) * 60).round();
  // 7.999 rounds to 60 seconds, which is 8:00 and not 7:60.
  final carried = seconds == 60;
  final shown = carried ? 0 : seconds;
  return '${minutes + (carried ? 1 : 0)}:${shown.toString().padLeft(2, '0')}';
}

/// `10` → `+10`, `-10` → `−10`, `0` → `0`.
///
/// The minus is U+2212, which is the glyph the rest of this app's figures use
/// (`activity_sections.dart`, `history_panel.dart`); a hyphen at 22 px beside a
/// tabular figure reads as a dash rather than a sign.
String? driftLabel(double? bpm) {
  if (bpm == null || !bpm.isFinite) {
    return null;
  }
  final rounded = bpm.round();
  if (rounded == 0) {
    return '0';
  }
  return rounded > 0 ? '+$rounded' : '−${-rounded}';
}
