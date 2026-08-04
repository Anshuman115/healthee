/// The refusal the app owes when the STRAP did not record something.
///
/// Distinct from every refusal the SERVER sends, and the two must not be merged.
/// They answer the same question — "why is there no number?" — with genuinely
/// different answers, and the owner's next move differs:
///
/// ```text
///   not_measured_by_strap   the sensor wrote nothing. Wear it; it comes back.
///   (server withhold)       the sensor wrote plenty; the gate declined anyway,
///                           and the block says what would change that.
/// ```
///
/// Collapsing them into one "no data" would tell someone whose strap was on the
/// bedside table to log a weight, and someone whose weight is stale to wear their
/// strap more. Both are wrong, and both are the kind of wrong that stops a person
/// acting on their own data.
///
/// The message names the strap explicitly rather than saying "no data
/// available", because "available" is a passive that hides who is missing what.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';

/// The reason id a not-recorded-by-the-strap refusal carries.
const String notMeasuredReason = 'not_measured_by_strap';

/// Why [name] has no value: the strap did not record it.
///
/// The remedy is real and is the owner's — this is a withhold in the full
/// original sense, unlike the server-derived one, and the sentence says the
/// thing that actually fixes it.
Disclosure notMeasuredDisclosure(String name) => Disclosure(
  reason: notMeasuredReason,
  message:
      'The strap recorded no $name for this day. It samples on its own '
      'schedule and only while it is worn — wear it and sync, and this fills '
      'in. Nothing is estimated in the meantime.',
);

/// [name]'s reading when the strap recorded nothing for it.
Reading<T> notMeasured<T extends Object>(String name) =>
    Withheld<T>(notMeasuredDisclosure(name));
