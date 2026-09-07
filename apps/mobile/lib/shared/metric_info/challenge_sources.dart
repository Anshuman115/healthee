/// The ⓘ bundle for one challenge, built once for every surface that draws one.
///
/// Three do: the v02 challenge card, the pre-v02 card behind the challenge hub,
/// and Today's focus list. A challenge's `title` is server-written prose with
/// inline `[note_id]` markers, and the payload sends `citations` beside it; three
/// hand-built bundles would be three chances for one surface to show a reader
/// fewer sources than another for the same commitment.
///
/// It lives here rather than on `Challenge` because [MetricDetail] is a UI type
/// and the model may not reach up into `shared/` — and it may not live beside one
/// of the three cards either, since `shared/today_focus.dart` would then be
/// importing a feature (Standards section 1: never sideways, never upward).
library;

import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';

/// What [challenge]'s title cites. Empty when it cites nothing, so the caller
/// can gate its ⓘ on it — a dot opening an empty sheet is worse than no dot.
MetricDetail challengeSources(Challenge challenge) => MetricDetail.grounded(
  challenge.grounding,
  // The title with its markers taken out, so the sheet's heading reads as the
  // commitment does on the card rather than as the raw field off the wire.
  title: parseGrounded(challenge.title).prose,
);
