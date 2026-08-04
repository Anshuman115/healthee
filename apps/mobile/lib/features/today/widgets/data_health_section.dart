/// The freshness strip — the owner-facing operational view, and it matters.
///
/// Brief §5.8: *"production has served stale data behind a healthy-looking
/// screen before. The strip must make 'this number is 85 hours old' impossible
/// to miss without being alarming."*
///
/// Four facts live here and they are genuinely different:
///
/// ```text
///   session      whether this phone is signed in to a server at all
///   feeds        which streams have gone quiet, and for how long
///   provenance   whether this whole payload came off disk, and when
///   backlog      how much the phone is holding that the server has not seen
/// ```
///
/// The second is the server's view of what it received; the rest are this
/// phone's view of what it sent. A screen that showed only the second would look
/// perfectly healthy on a phone whose push has been failing for a week — the
/// server's feeds *are* fresh, up to the last thing it heard.
///
/// It renders nothing when all four are quiet. That silence is what makes it
/// worth reading when it speaks — and it is why a deliberate mid-drain pause is
/// no longer allowed to raise its voice here. `health_lines.dart` owns which
/// sentences are true and which of them the owner has to act on; this file only
/// renders them, and the loud/quiet difference is typographic because colour in
/// this app is a claim about the owner's body (`README.md`).
///
/// ## The one data-loss risk gets a sentence of its own
///
/// The push backlog cannot be lost — it is in the durable local store and
/// nothing is marked sent until the server acknowledges it. The **strap's** ring
/// buffer can be: it overwrites, and a first-ever sync suggested it holds on the
/// order of nine days. So the honest guard is a warning when the band has gone
/// unread long enough to be approaching that, while opening the app near it
/// still fixes everything. See [kStrapHorizonWarning].
///
/// ## Why "not signed in" belongs here rather than in a redirect
///
/// Without a token every `/api/*` call is a 401, so the derived half of Today
/// goes quiet and the strip's own subject — *why is this screen not current* —
/// has exactly one answer. Saying "nothing has synced" while the real cause is
/// that the app was never signed in is the stale-behind-a-healthy-screen failure
/// this strip exists to prevent, one step further back.
///
/// It is a sentence and a link, **not a wall**: everything the strap measured is
/// on the screen below it and stays there. The router deliberately does not
/// redirect (see `core/router.dart`).
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/data_health.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// What is stale, what is cached, and what has not been sent.
class DataHealthSection extends StatelessWidget {
  /// Any of [health], [push], [cachedAt] or [lastStrapSync] may be null; the
  /// card renders only what it actually has something to say about.
  const DataHealthSection({
    this.health,
    this.push,
    this.cachedAt,
    this.cachedDate,
    this.lastStrapSync,
    this.now,
    this.signedIn,
    this.onSignIn,
    super.key,
  });

  /// Whether this phone holds a server session. **Null means not yet known** —
  /// the keystore read is asynchronous, and announcing "not signed in" during it
  /// would flash the invitation at an owner who already is.
  final bool? signedIn;

  /// Opens the sign-in screen. Null in tests and wherever there is no route.
  final VoidCallback? onSignIn;

  /// Per-feed freshness from the server.
  final DataHealth? health;

  /// This phone's push state.
  final PushStamp? push;

  /// When the payload on screen was received, if it came from the cache.
  final DateTime? cachedAt;

  /// Which day that cached payload describes, when it is not today's.
  final String? cachedDate;

  /// When the strap itself was last read completely. The band's ring buffer is
  /// the one thing here that can genuinely lose data — see the library docstring.
  final DateTime? lastStrapSync;

  /// The current instant, injected so tests do not read the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final at = now ?? DateTime.now();
    final feeds = health?.degraded ?? const [];
    final lines = dataHealthLines(
      now: at,
      push: push,
      lastStrapSync: lastStrapSync,
      cachedAt: cachedAt,
      cachedDate: cachedDate,
    );
    final signedOut = signedIn == false;
    if (feeds.isEmpty && lines.isEmpty && !signedOut) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data health', style: text.labelSmall),
          if (signedOut) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'This phone is not signed in to a Healthee server. Everything '
              'your strap measured is below and is still being recorded here; '
              'the readings the server works out — recovery, sleep health, '
              'debt, VO₂max, biological age — need a sign-in.',
              style: text.bodyMedium?.copyWith(color: colors.ink),
            ),
            if (onSignIn case final VoidCallback open) ...[
              const SizedBox(height: Insets.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: open,
                  child: const Text('Sign in to your server'),
                ),
              ),
            ],
          ],
          for (final line in lines) ...[
            const SizedBox(height: Insets.sm),
            Text(
              line.text,
              // The only difference a loud line gets. No colour: `unf` is not a
              // warning colour and there is exactly one red in this app, for
              // illness. Full ink at body size against secondary ink one step
              // down is enough to order two sentences without claiming anything
              // about the owner's health.
              style: line.loud
                  ? text.bodyMedium?.copyWith(color: colors.ink)
                  : text.bodySmall?.copyWith(color: colors.ink2),
            ),
          ],
          if (feeds.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            for (final feed in feeds)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: _FeedRow(feed: feed),
              ),
          ],
        ],
      ),
    );
  }

}

/// One quiet feed: what it is, and how long it has been quiet.
class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.feed});

  final FeedHealth feed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        // A thin left mark rather than a tinted row: brief §2 puts state accents
        // on a border, never on a nested container.
        Container(width: 2, height: 22, color: colors.unf),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(feed.label, style: text.titleSmall)),
        Text(
          _age(feed),
          style: text.labelMedium?.copyWith(color: colors.ink2),
        ),
      ],
    );
  }

  /// "Nothing has synced in 85 hours" is the brief's own example, and the hours
  /// are the load-bearing part — a status word alone hides the scale.
  static String _age(FeedHealth feed) {
    final hours = feed.ageHours;
    if (hours == null) {
      return 'never';
    }
    return hours < 48
        ? '${hours.round()} h ago'
        : '${(hours / 24).floor()} d ago';
  }
}
