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
/// ## The data-loss risks get sentences of their own
///
/// The push backlog is durable: nothing is marked sent until the server
/// acknowledges it, and `horizon_prune.dart` keeps an unsent measurement past
/// the 60-day horizon rather than pruning it with the rest. The **strap's** ring
/// buffer is not: it overwrites, and a first-ever sync suggested it holds on the
/// order of nine days. So the honest guard is a warning when the band has gone
/// unread long enough to be approaching that, while opening the app near it
/// still fixes everything. See [kStrapHorizonWarning].
///
/// One case survives both guards — a queue stuck for a year, at which point the
/// phone does stop holding samples. That is stated here permanently and in full
/// ink, never as maintenance; `health_lines.dart` owns the sentence.
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
///
/// ## Why the RADIO's faults are printed here too
///
/// The top connection strip is gone (owner, 2026-08-05). It carried two faults
/// that exist nowhere else — an unreachable strap and a phone that has never
/// synced — and neither has a [HealthLine], because `health_lines.dart` is a
/// pure function of stored facts and both are facts about a live socket. A ring
/// round an avatar cannot say *"Bluetooth is off — turn Bluetooth on and try
/// again"*.
///
/// So [connection] arrives here and its `linkAlerts` are printed **first**: they
/// are the faults the owner can usually fix in ten seconds, and this is now the
/// only place their remedy appears. `LinkReport.freshness` comes with them,
/// because *"we cannot reach the strap"* without *"and your numbers are from 9 h
/// ago"* is half the news.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/data_health.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// What is stale, what is cached, and what has not been sent.
class DataHealthSection extends StatelessWidget {
  /// Any of [health], [push], [cachedAt] or [lastStrapSync] may be null; the
  /// card renders only what it actually has something to say about.
  const DataHealthSection({
    this.health,
    this.connection,
    this.push,
    this.cachedAt,
    this.cachedDate,
    this.lastStrapSync,
    this.now,
    this.signedIn,
    this.onSignIn,
    this.bottomGap = 0,
    super.key,
  });

  /// The classified connection, for the radio's own faults. See the docstring.
  ///
  /// Null means nothing has classified one — a widget test pumping this card
  /// alone — and draws no link section rather than a reassuring absence.
  final ConnectionHealth? connection;

  /// Space under the card, applied **only when the card renders**.
  ///
  /// Legacy's banner carries its own `EdgeInsets.only(bottom: 16)` inside the
  /// widget (`today_screen.dart:663`) precisely so a healthy day leaves no gap
  /// behind it. A gap supplied by the section list could not do that: the list
  /// cannot see that this returned `SizedBox.shrink()`, so a quiet day would
  /// open with sixteen pixels of nothing.
  final double bottomGap;

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
    // The signed-out sentence comes from `health_lines.dart` like every other
    // one now, rather than being written here: the connection indicator shows
    // the SHORT form of each loud line, and a sentence living in a widget is one
    // the chrome could only reach by copying it.
    final lines = dataHealthLines(
      now: at,
      push: push,
      lastStrapSync: lastStrapSync,
      cachedAt: cachedAt,
      cachedDate: cachedDate,
      signedIn: signedIn,
    );
    final signedOut = signedIn == false;
    final link = connection?.linkAlerts ?? const <ConnectionAlert>[];
    if (feeds.isEmpty && lines.isEmpty && link.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: _card(colors, text, feeds, lines, link, signedOut),
    );
  }

  Widget _card(
    HealtheeColors colors,
    TextTheme text,
    List<FeedHealth> feeds,
    List<HealthLine> lines,
    List<ConnectionAlert> link,
    bool signedOut,
  ) {
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data health', style: text.labelSmall),
          // The radio first, and only this card carries its remedy.
          for (final alert in link) ...[
            const SizedBox(height: Insets.sm),
            Text(
              alert.headline,
              style: text.bodyMedium?.copyWith(color: colors.ink),
            ),
            if (connection?.report.freshness case final String age) ...[
              const SizedBox(height: Insets.xs),
              Text(age, style: text.bodySmall?.copyWith(color: colors.ink2)),
            ],
            if (alert.detail case final String remedy) ...[
              const SizedBox(height: Insets.xs),
              Text(remedy, style: text.bodySmall?.copyWith(color: colors.ink2)),
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
          // The one action this card offers, and it belongs to exactly one line.
          if (signedOut)
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
