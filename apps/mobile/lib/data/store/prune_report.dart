/// What a horizon prune removed — and, kept apart from it, what it destroyed.
///
/// Two counts rather than one total, because they are not the same event and a
/// single number would let the second hide inside the first. Dropping a cached
/// server payload costs nothing: the server still holds it and will send it
/// again. Dropping a measurement the server has never seen is the end of that
/// measurement — the strap's ring buffer overwrites in about a week or two, so
/// there is nowhere left to read it from.
///
/// `pruneBefore` used to return one `int` covering both, which is exactly how a
/// data loss becomes a maintenance statistic.
library;

import 'package:meta/meta.dart';

/// One pass of the horizon, counted by what the rows meant.
@immutable
class PruneReport {
  /// All zero — the report of a prune that found nothing to do.
  const PruneReport({
    this.cachedPayloads = 0,
    this.sentMeasurements = 0,
    this.unsentSamples = 0,
    this.unsentThroughDay,
  });

  /// Cached server payloads dropped. Re-fetchable, therefore not a loss.
  final int cachedPayloads;

  /// Measurements dropped that the server had already acknowledged. Safe: the
  /// server is their durable home and this phone was only the courier.
  final int sentMeasurements;

  /// Measurements dropped that the server has **never** seen.
  ///
  /// Only ever samples — see `horizon_prune.dart` for why the three
  /// event-per-day tables have no second bound and so can never contribute here.
  final int unsentSamples;

  /// The newest calendar day among [unsentSamples], `YYYY-MM-DD`, or null when
  /// nothing was lost. Reported rather than the cutoff we asked for: the cutoff
  /// is what we intended, this is what was actually there.
  final String? unsentThroughDay;

  /// Every row this pass removed, of any kind. For the sync summary line.
  int get rows => cachedPayloads + sentMeasurements + unsentSamples;

  /// Whether this pass ended a measurement's life. Never true silently.
  bool get destroyedSomething => unsentSamples > 0;
}

/// Measurements this phone deleted before the server ever saw them.
///
/// Durable and **cumulative**: written into [SyncMeta] by the prune, read back
/// by `PushReader.lastAttempt`, and never cleared. Nothing on this phone and
/// nothing on any server can undo it, so there is no action that would make
/// clearing it honest — and a card that quietly stops mentioning destroyed data
/// once the queue looks tidy again is the flattery this product is built to
/// refuse.
@immutable
class UnsentLoss {
  /// [rows] and [throughDay] are the two facts the owner needs; [at] is when the
  /// most recent such prune ran.
  const UnsentLoss({required this.rows, required this.throughDay, this.at});

  /// How many measurements have been destroyed here, over all prunes.
  final int rows;

  /// The newest calendar day any of them was recorded on, `YYYY-MM-DD`.
  final String throughDay;

  /// When the most recent destroying prune ran.
  final DateTime? at;
}
