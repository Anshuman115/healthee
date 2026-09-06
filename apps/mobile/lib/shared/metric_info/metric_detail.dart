/// What a card used to print on its own face, on its way to the ⓘ sheet.
///
/// ## The defect this type exists to fix
///
/// The owner, on the installed v02 build: *"that reference pill can we remove
/// those from cards please info sheets are for that"* and *"all these
/// unnecessary Sleep regularity long text and other texts in pills in
/// evrycard"*. Two reports, one shape: a card carrying its own **method and
/// provenance** — the reference it is read against, the sources behind it, the
/// paragraph explaining what the bars are — inline, under the number.
///
/// The ⓘ sheet already existed for exactly that material. What was missing was a
/// way to get a card's OWN, payload-derived provenance into it: [MetricInfo] is a
/// compile-time map, and `health.researchNotes` / `mvpa.weekTarget` /
/// `vo2max.standardErrorSource` are things only the payload knows.
///
/// So a card hands its head one of these, the head hands it to the ⓘ, and the
/// sheet renders it beside the static explainer. One destination for every kind
/// of long-form method text, which is what the owner asked for.
///
/// ## The rule that makes this a move rather than a deletion
///
/// **Nothing may be dropped on the way.** A claim whose grounding becomes
/// unreachable is a regression, not a tidy-up: it leaves a number on screen with
/// its licence removed. So every card that loses a citation must gain a reachable
/// ⓘ carrying it, and `MetricInfoDot` therefore draws itself for a card with
/// **no explainer at all** as long as this bundle is non-empty — an ⓘ that opens
/// a sheet holding only the sources is still the sources, reachable.
/// `test/features/card_provenance_test.dart` enumerates the cards and asserts it.
///
/// ## What does NOT belong here
///
/// A caveat signpost, a withheld reason, clinical routing, "not a diagnosis",
/// and the naming of the instrument behind a reading all stay **on the card**.
/// Those are not method detail; they are the qualifications that make the number
/// on the card readable at all, and this project has already fixed one round of
/// hiding them (`states/caveat_disclosure.dart`). The line is: text that
/// *teaches or describes* moves; text that *qualifies the number beside it*
/// stays.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:meta/meta.dart';

/// One card's own provenance, bound for its ⓘ sheet.
@immutable
class MetricDetail {
  /// Builds a bundle. Every field is optional; an empty one draws no ⓘ.
  const MetricDetail({
    this.title,
    this.notes = const <String>[],
    this.source,
    this.references = const <String>[],
    this.method = const <String>[],
    this.disclosures = const <Disclosure>[],
    this.disclosuresLabel,
  });

  /// The bundle a card with nothing to disclose passes. Also the default.
  static const MetricDetail none = MetricDetail();

  /// The sheet's heading when this card has no [MetricInfo] entry to name it.
  ///
  /// Null is fine when there IS an explainer — the explainer's own title wins,
  /// because two names for one metric is the drift `metric_names.dart` exists to
  /// prevent.
  final String? title;

  /// The corpus note ids the payload sent for THIS card, e.g.
  /// `sleep_health.research_notes`. Merged with the explainer's own in the sheet
  /// and de-duplicated, so a note cited by both is one chip.
  final List<String> notes;

  /// A human sentence about the source, when the payload carried one —
  /// VO₂max's `see_source` is the live example. Rendered verbatim.
  final String? source;

  /// The published references the card's figures are read against —
  /// `Efficiency — reference ≥ 85%`, `Active minutes — reference 150 min/week`.
  ///
  /// These were the "reference pills" the owner asked us to take off the cards.
  /// They are **kept**, not deleted: a cutoff with no source is a number this
  /// app made up, and the sheet is where a reader who wants it can find it.
  final List<String> references;

  /// The explanatory prose that used to sit under the card's chart — what the
  /// bars are, what the colours mean, how the model divides.
  final List<String> method;

  /// Server disclosures too long to print on the card: the withheld
  /// `consequence` and its per-term messages, and the permanent exclusions.
  ///
  /// The card keeps a short signpost naming them; this is the full text, one tap
  /// behind it. Same shape as the caveat fix (`states/caveat_disclosure.dart`).
  final List<Disclosure> disclosures;

  /// What to call [disclosures] on the sheet. Defaults in the sheet itself.
  final String? disclosuresLabel;

  /// True when there is nothing here worth an ⓘ of its own.
  bool get isEmpty =>
      notes.isEmpty &&
      source == null &&
      references.isEmpty &&
      method.isEmpty &&
      disclosures.isEmpty;

  /// The negation, for a call site that reads better positively.
  bool get isNotEmpty => !isEmpty;
}
