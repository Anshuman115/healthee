/// A Today payload **plus where it came from and when**.
///
/// The snapshot alone is not enough to render honestly. Brief §7.4 requires the
/// app to be fully readable with no network, and the only way to do that is to
/// draw the last payload the server sent — which means the screen is sometimes
/// showing yesterday. Presenting that as today is the stale-as-current failure
/// this product has already shipped once, so the provenance travels with the
/// payload rather than being inferred at the render.
///
/// Two fields carry it: [fetchedAt] (when the server said this) and [fromCache]
/// (whether the network answered on this build of the screen). A card that shows
/// a number reads both, and the data-health strip says the sentence out loud.
library;

import 'package:healthee/data/models/today_snapshot.dart';
import 'package:meta/meta.dart';

/// What the server said, when it said it, and whether we heard it just now.
@immutable
class TodayView {
  /// Built by `TodayRepository`.
  const TodayView({
    required this.snapshot,
    required this.fetchedAt,
    required this.fromCache,
  });

  /// The parsed payload.
  final TodaySnapshot snapshot;

  /// When this payload was received from the server — NOT when it was rendered.
  final DateTime fetchedAt;

  /// True when the network did not answer and this came off the local tier.
  ///
  /// Deliberately not "is it stale". Staleness is a judgement about a duration
  /// and it belongs to the surface that draws it; this is a fact about where the
  /// bytes came from, and facts are what a data layer is allowed to have.
  final bool fromCache;

  /// How old this payload is at [now].
  Duration ageAt(DateTime now) => now.difference(fetchedAt);

  /// Whether the payload describes a different calendar day than [today].
  ///
  /// The case the sentence must not soften: a phone that went offline before
  /// midnight is holding a complete, correct snapshot **of yesterday**, and
  /// every number on it is a claim about a day the owner has already finished.
  bool describesAnotherDay(String today) => snapshot.date != today;
}
