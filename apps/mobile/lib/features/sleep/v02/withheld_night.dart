/// The one honesty surface that sits near the top of Sleep.
///
/// `/api/sleep` returns the most recent session it has, which on a night the
/// strap was not worn is **not last night**. Everything under it — the stage
/// timeline, the checks, the vitals — is then a true reading of an older night,
/// and the only wrong thing on the screen would be the reader's assumption
/// about which night it is.
///
/// The prototype has no box for this, and it is drawn anyway, above the reading
/// rather than after it: a sentence saying *everything below is from an older
/// night* is worth nothing underneath the thing it qualifies. That is the
/// honesty layer, which is where this rebuild has latitude.
///
/// It is v02's `.notice`, not a shape of its own — `HNotice` is the container
/// the prototype uses for exactly this kind of line.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/v02/notices.dart';

/// `No sleep recorded last night` — and which night the screen is showing.
class StaleNightNotice extends StatelessWidget {
  /// [label] is `Night before last` · `3 nights ago`.
  const StaleNightNotice({required this.label, super.key});

  /// The notice's title.
  static const String title = 'No sleep recorded last night';

  /// Which night the rest of the screen is about.
  final String label;

  @override
  Widget build(BuildContext context) => HNotice(
    title: title,
    body: 'Everything below is your last recorded sleep · $label.',
  );
}
