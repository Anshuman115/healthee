/// `GET /api/entitlement`, typed — what this owner may use, and how much is left.
///
/// The endpoint's own docstring is the contract: it is ungated (a locked-out owner
/// is exactly who needs to read it), uncached (a cancellation shows on the next
/// poll), and it is a **display hint** rather than the access decision — every
/// premium route re-checks server-side, so a client that lied to itself would
/// still get 402 from everything that matters.
///
/// ## `included` is a meter, and its absences mean things
///
/// `api/allowance_report.py` documents three shapes and they are not
/// interchangeable, so this model keeps them distinguishable rather than
/// flattening them to a number:
///
/// ```text
///   an entry with limit/used/remaining   a capped feature — render the meter
///   NO entry, premium owner              uncapped: unlimited, never "0"
///   NO entries at all, free owner        they bought nothing — `locked` is their story
/// ```
///
/// That is why [Entitlement.allowanceFor] returns a nullable and why nothing here
/// defaults a missing meter to zero: "0 of 20 left" for somebody who has no access
/// at all is an upsell disguised as a meter, and for a subscriber with an uncapped
/// feature it is the exact inversion of what they paid for.
///
/// The balance is **read**, never computed: `remaining` comes off the wire because
/// a client subtracting it is a client that can subtract it differently from the
/// gate that enforces it.
library;

import 'package:meta/meta.dart';

/// The feature id the coach is metered under, server-side (`api/gate.py`).
const String kCoachFeature = 'coach';

/// One capped feature's meter, as `/api/entitlement` reports it.
@immutable
class IncludedAllowance {
  /// Built by [IncludedAllowance.fromJson].
  const IncludedAllowance({
    required this.feature,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.windowDays,
    required this.resetsAt,
  });

  /// Parses one `included[]` entry.
  factory IncludedAllowance.fromJson(Map<String, Object?> json) {
    return IncludedAllowance(
      feature: json['feature']! as String,
      limit: (json['limit']! as num).toInt(),
      used: (json['used']! as num).toInt(),
      remaining: (json['remaining']! as num).toInt(),
      windowDays: (json['window_days']! as num).toInt(),
      resetsAt: switch (json['resets_at']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
    );
  }

  /// `coach`, and whatever else the gate caps later.
  final String feature;

  /// How many the subscription includes per window.
  final int limit;

  /// How many have been spent inside the window.
  final int used;

  /// What is left. The server's own subtraction, not ours.
  final int remaining;

  /// The rolling window, in days.
  final int windowDays;

  /// When the window reopens. **Null while any slot is free** — the server only
  /// sends it once the window is full, because a reset instant beside "17 left"
  /// would read as a countdown that is not running.
  final DateTime? resetsAt;

  /// Whether asking one more question is possible right now.
  bool get hasRemaining => remaining > 0;
}

/// One owner's premium state, what is locked, and what is left of what they bought.
@immutable
class Entitlement {
  /// Built by [Entitlement.fromJson].
  const Entitlement({
    required this.premium,
    required this.status,
    required this.locked,
    required this.included,
    required this.upgradeUrl,
  });

  /// Parses `GET /api/entitlement`.
  factory Entitlement.fromJson(Map<String, Object?> json) {
    return Entitlement(
      premium: json['premium'] == true,
      status: json['status'] as String? ?? 'unknown',
      locked: <String>[
        for (final entry in (json['locked'] as List? ?? const []))
          if (entry is String) entry,
      ],
      included: <IncludedAllowance>[
        for (final entry in (json['included'] as List? ?? const []))
          if (entry is Map<String, Object?>) IncludedAllowance.fromJson(entry),
      ],
      upgradeUrl: json['upgrade'] as String?,
    );
  }

  /// Whether the subscription is live.
  final bool premium;

  /// `active` · `expired` · … — the server's own word for the subscription.
  final String status;

  /// Everything this owner cannot use right now. Empty for a subscriber.
  final List<String> locked;

  /// The meters on the caps they already bought. Empty for everyone else.
  final List<IncludedAllowance> included;

  /// Where to subscribe, when the server offered a link.
  final String? upgradeUrl;

  /// The meter for [feature], or null when there is none.
  ///
  /// **Null is three different things** and the caller has to say which it means
  /// (see the library docstring): uncapped for a subscriber, nothing bought for a
  /// free owner, or a feature the gate does not meter. It is never zero.
  IncludedAllowance? allowanceFor(String feature) {
    for (final allowance in included) {
      if (allowance.feature == feature) {
        return allowance;
      }
    }
    return null;
  }

  /// Whether [feature] is refused outright for this owner today.
  bool isLocked(String feature) => locked.contains(feature);
}
