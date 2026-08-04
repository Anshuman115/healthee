/// The ONE place a server payload becomes a [Reading].
///
/// ## Why this is a single function rather than a line in each model
///
/// The server spreads a value's honesty across **sibling keys**: the value field
/// itself, `data_confidence`, `withheld`, `excluded`, `caveats`. Deciding which
/// [Reading] case that adds up to is a rule, and a rule written into twenty
/// `fromJson` bodies is twenty chances to write it nineteen ways. The server had
/// exactly this problem and solved it exactly this way — `derive/freshness.py`
/// exists because "five checks is how a metric ends up with two definitions of
/// 'current'".
///
/// So: models parse their own *fields*; they never decide their own *honesty*.
/// This function decides, once, for all of them.
///
/// ## The precedence, and why it is this order
///
/// 1. **`withheld` present** → [Withheld], whatever else the payload says. The
///    server's contract is that the current-looking field is null alongside it, so
///    there is nothing to report even if a stale number is sitting in the block.
/// 2. **no value** → [Withheld] with whatever reason we can name. A null value
///    with no explanation is the one state that must not reach the UI silently,
///    so it is given the honest fallback sentence rather than being dropped.
/// 3. **`excluded` non-empty and no value** → [Excluded]. Note the *and*: the
///    biological-age payload carries both a number and an `excluded` list, because
///    the exclusions describe levers left OUT of a number that still exists. An
///    exclusion never suppresses a value it merely narrows.
/// 4. **`caveats` non-empty** → [Caveated].
/// 5. otherwise → [Present].
///
/// Excluded-with-a-value is the case worth stating plainly, because it is the one
/// a reasonable person gets wrong: those disclosures ride along with the value as
/// caveats, since that is what they are doing to it.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';

/// The sentence used when a payload gives us no value and no reason.
///
/// The server always sends one; this covers the shape drifting without warning.
/// It is deliberately not reassuring — an absence we cannot explain is worse than
/// one we can, and the copy should not hide that.
const String unexplainedAbsenceMessage =
    'No value for today, and the server did not say why. Try syncing; if this '
    'persists it is a bug on our side, not a gap in your data.';

/// The reason id paired with [unexplainedAbsenceMessage].
const String unexplainedAbsenceReason = 'unexplained_absence';

const Disclosure _unexplainedAbsence = Disclosure(
  reason: unexplainedAbsenceReason,
  message: unexplainedAbsenceMessage,
);

/// Folds one server block into a [Reading].
///
/// [json] is the object carrying the value and its sibling honesty keys.
/// [value] extracts the value from that same object, returning null when the
/// server withheld it. Everything else is read here.
///
/// ```dart
/// final vo2max = readingFrom(json['vo2max'], Vo2max.fromJson);
/// ```
Reading<T> readingFrom<T extends Object>(
  Map<String, Object?> json,
  T? Function(Map<String, Object?> json) value,
) {
  final withheld = _disclosure(json['withheld']);
  if (withheld != null) {
    return Withheld<T>(withheld);
  }

  final parsed = value(json);
  final excluded = _disclosures(json['excluded']);
  final caveats = _disclosures(json['caveats']);

  if (parsed == null) {
    // No value and no `withheld` block. If the payload said anything at all about
    // why, use it; a permanent exclusion is a different answer from a temporary
    // one and keeps its own case.
    if (excluded.isNotEmpty) {
      return Excluded<T>(excluded);
    }
    return Withheld<T>(_unexplainedAbsence);
  }

  // A value DID arrive. Exclusions here describe levers left out of it rather
  // than a refusal to report it, so they travel with it exactly as caveats do.
  final attached = [...caveats, ...excluded];
  return attached.isEmpty ? Present<T>(parsed) : Caveated<T>(parsed, attached);
}

/// Folds a payload whose value is a bare number rather than an object.
///
/// The Today metric cards are shaped this way: `value` sits beside `withheld` and
/// `caveats` in the same object. Same rule, applied through the same function, so
/// a metric card and a VO₂max card cannot disagree about what "withheld" means.
Reading<double> numericReadingFrom(Map<String, Object?> json, String field) {
  return readingFrom<double>(json, (row) => (row[field] as num?)?.toDouble());
}

Disclosure? _disclosure(Object? raw) {
  if (raw is! Map<String, Object?>) {
    return null;
  }
  // A block with no reason or no message cannot be rendered honestly, and
  // inventing the missing half would be worse than admitting the gap. Treated as
  // absent so the caller's "no value, no reason" path names it.
  if (raw['reason'] is! String || raw['message'] is! String) {
    return null;
  }
  return Disclosure.fromJson(raw);
}

List<Disclosure> _disclosures(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final entry in raw)
      if (_disclosure(entry) case final Disclosure disclosure) disclosure,
  ];
}
