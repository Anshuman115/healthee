/// The step figure a day is read against — from the corpus, never from folklore.
///
/// **`steps_mortality` forbids the flat "10,000 steps" outright**, in a
/// directive rather than a suggestion:
///
/// > Do **not** present "10,000 steps" as a target. Use the age-banded plateau
/// > Paluch 2022 actually reports: **~8,000–10,000/day under 60**,
/// > **~6,000–8,000 at 60+**.
///
/// The note is blunter still in its summary: *"the 10,000-step target is a
/// marketing artifact"*. It is — the number is the name of a 1965 Japanese
/// pedometer, not a finding.
///
/// So the target here is **derived**, not chosen. For an owner under 60 the top
/// of the plateau is 10,000, which is the same figure folklore quotes and the
/// only reason this file can honour a request for it; at 60 it becomes 8,000 on
/// its own, without anybody remembering to change a constant.
///
/// ## Why this is a Dart file and not a string in `metric_info`
///
/// Because that is precisely how the last wrong step target shipped. Legacy put
/// *"~7,500/day"* in a `metric_info` explainer, where `insights/validator.py`
/// calibrates against a cited note's grade and **cannot see a Dart string** — so
/// a number in no note at all served for months, under-targeting this owner by
/// ~2,500 steps a day. What makes this file different is not that it is Dart: it
/// is that the band is transcribed with its source, and a test asserts the
/// transcription against `packages/knowledge/notes/activity/steps_mortality.md`.
/// A deterministic surface is guarded by a test, not by the citation validator.
///
/// **Nothing here is a recommendation.** The plateau is where the mortality
/// curve stops improving in Paluch 2022's cohort; the note's own Safety bounds
/// section keeps death-risk figures off every surface, and the tile draws a
/// proportion, not a verdict.
library;

/// The research note this band is transcribed from.
const String kStepsPlateauNoteId = 'steps_mortality';

/// The age the note's two bands are divided at.
const int kStepsPlateauAgeSplit = 60;

/// The plateau's top for an owner under [kStepsPlateauAgeSplit].
const int kStepsPlateauTopUnder60 = 10000;

/// And at or over it.
const int kStepsPlateauTopFrom60 = 8000;

/// The step count a day is drawn against, or null when the age is unknown.
///
/// **Null rather than a default.** An owner whose age nothing has read is not an
/// owner who is under 60; a tile with no denominator draws no meter, which is
/// what it did before this file existed and remains the honest answer.
int? stepsPlateauTop(double? chronologicalAge) {
  if (chronologicalAge == null || !chronologicalAge.isFinite) {
    return null;
  }
  return chronologicalAge < kStepsPlateauAgeSplit
      ? kStepsPlateauTopUnder60
      : kStepsPlateauTopFrom60;
}
