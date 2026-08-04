/// [Disclosure] — the sentence the server attaches when a number needs one.
///
/// One class for all three of the server's blocks (`withheld`, `excluded`,
/// `caveats`) because they genuinely have one shape: a machine-filterable
/// `reason`, a second-person `message`, and some dating. What differs between
/// them is not their fields but what they MEAN, and that difference is carried by
/// which [Reading] case holds them — not by a `kind` string that a `switch`
/// default could swallow.
///
/// See `apps/server/src/healthee/derive/freshness.py` for the producing side;
/// `withheld_block` and `caveat_block` sit next to each other there deliberately,
/// "so the choice between them is visible as a choice".
library;

import 'package:meta/meta.dart';

/// Why a number is missing, or which way a reported one leans.
@immutable
class Disclosure {
  /// Builds a disclosure. Only [reason] and [message] are always present.
  const Disclosure({
    required this.reason,
    required this.message,
    this.term,
    this.asOfDate,
    this.ageDays,
  });

  /// Parses one server block.
  ///
  /// A block with no `message` is dropped by the caller rather than rendered
  /// blank — see [package:healthee/data/honesty/envelope]. That is why this does
  /// not invent a fallback sentence: a disclosure whose text we made up is worse
  /// than one we admit we did not receive.
  factory Disclosure.fromJson(Map<String, Object?> json) {
    return Disclosure(
      reason: json['reason']! as String,
      message: json['message']! as String,
      term: json['term'] as String?,
      // `withheld` dates the last value we DID have as `last_as_of_date`;
      // `caveats` date the input they are about as `as_of_date`. One field here,
      // because a UI only ever asks "what date is this sentence about".
      asOfDate: (json['last_as_of_date'] ?? json['as_of_date']) as String?,
      ageDays: (json['age_days'] as num?)?.toInt(),
    );
  }

  /// A stable id an operator can filter on, e.g. `logged_weight_stale`.
  ///
  /// Never shown to the owner on its own. It is the key, [message] is the text.
  final String reason;

  /// The second-person sentence: what happened and, for a withhold, what would
  /// fix it. This is what the owner reads.
  final String message;

  /// Which component of a composite this is about (`fitness`, `regularity`, …),
  /// when the payload says. Null for whole-metric disclosures.
  final String? term;

  /// The date this sentence is about — the last day we had a value, or the date
  /// of the input that tilts one. `YYYY-MM-DD`, null when the payload omits it.
  final String? asOfDate;

  /// How far [asOfDate] is from the day in question, in days.
  final int? ageDays;

  @override
  bool operator ==(Object other) =>
      other is Disclosure &&
      other.reason == reason &&
      other.message == message &&
      other.term == term &&
      other.asOfDate == asOfDate &&
      other.ageDays == ageDays;

  @override
  int get hashCode => Object.hash(reason, message, term, asOfDate, ageDays);

  @override
  String toString() => 'Disclosure($reason)';
}
