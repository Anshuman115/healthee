/// Per-feed freshness — "the trust card" (`docs/APP_DESIGN.md` §3.1).
///
/// The one card that renders **nothing** when everything is fresh. It is the
/// confidence mechanism made visible: when a feed goes quiet, the app says which
/// one and how long ago, instead of continuing to draw charts that have silently
/// stopped moving.
library;

import 'package:meta/meta.dart';

/// One data feed's freshness.
@immutable
class FeedHealth {
  /// A feed and how recently it reported.
  const FeedHealth({
    required this.metric,
    required this.label,
    required this.status,
    required this.ageHours,
    required this.lastIso,
  });

  /// Parses one entry of `data_health.items`.
  factory FeedHealth.fromJson(Map<String, Object?> json) {
    return FeedHealth(
      metric: json['metric']! as String,
      label: json['label']! as String,
      status: json['status']! as String,
      ageHours: (json['age_h'] as num?)?.toDouble(),
      lastIso: json['last_iso'] as String?,
    );
  }

  /// Feed id, e.g. `hrv`.
  final String metric;

  /// Owner-facing name, e.g. "HRV".
  final String label;

  /// `ok` or a degraded state.
  final String status;

  /// Hours since this feed last reported.
  final double? ageHours;

  /// The instant it last reported, ISO-8601.
  final String? lastIso;

  /// Whether this feed needs saying out loud.
  bool get isDegraded => status != 'ok';
}

/// Overall sync health plus the per-feed detail behind it.
@immutable
class DataHealth {
  /// Builds a health summary.
  const DataHealth({
    required this.overall,
    required this.syncStatus,
    required this.syncedAgeHours,
    required this.items,
  });

  /// Parses the `data_health` block.
  factory DataHealth.fromJson(Map<String, Object?> json) {
    return DataHealth(
      overall: json['overall'] as String? ?? 'ok',
      syncStatus: json['sync_status'] as String? ?? 'ok',
      syncedAgeHours: (json['synced_age_h'] as num?)?.toDouble(),
      items: [
        for (final entry in (json['items'] as List? ?? const []))
          if (entry is Map<String, Object?>) FeedHealth.fromJson(entry),
      ],
    );
  }

  /// `ok` when every feed is current.
  final String overall;

  /// Freshness of the sync itself, independent of any one feed.
  final String syncStatus;

  /// Hours since the last successful sync.
  final double? syncedAgeHours;

  /// Every feed, fresh or not.
  final List<FeedHealth> items;

  /// Just the feeds worth telling the owner about.
  List<FeedHealth> get degraded => [
    for (final item in items)
      if (item.isDegraded) item,
  ];

  /// True when the card should render at all. Fresh data says nothing.
  bool get needsAttention => overall != 'ok' || syncStatus != 'ok' || degraded.isNotEmpty;
}
