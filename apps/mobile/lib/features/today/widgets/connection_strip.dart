/// The connection state, in the chrome. Quiet, present tense, never a badge.
///
/// Brief §2 rations colour to judgement and forbids anything that congratulates
/// or demands attention, so this spends none: a small dot in [HealtheeColors.ink3]
/// when idle and [HealtheeColors.accent] when a session is live, the state's own
/// sentence beside it, and one text action. There is no green, because "green
/// means connected" is a convention that costs a colour the product reserves for
/// a reading being better than the owner's normal.
///
/// A failure does not become a dot either. `ConnectionFailed` carries the
/// original taxonomy's headline AND its remedy, and both are shown — the remedy
/// is the whole point of the failure being named rather than counted. That is
/// the brief's "surface them, do not collapse them to a dot", and it is why
/// `SyncFailure` copies the sentences instead of a code.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';

/// The chrome's one-line report on the link to the strap.
class ConnectionStrip extends ConsumerWidget {
  /// Watches [syncControllerProvider] and drives it.
  const ConnectionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: colors.chrome,
        border: Border(bottom: BorderSide(color: colors.line2, width: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StateDot(live: state is Connected || state is Syncing),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  state.headline,
                  style: text.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.isBusy)
                TextButton(
                  onPressed: controller.cancel,
                  child: const Text('Stop'),
                )
              else
                TextButton(
                  // `unawaited` is wrong here and `await` is impossible in a
                  // callback: the button's job is to START a sync, and the state
                  // this widget watches is how its progress reaches the screen.
                  onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
                  child: const Text('Sync now'),
                ),
            ],
          ),
          if (state is Syncing && state.progress != null) ...[
            const SizedBox(height: Insets.sm),
            _Progress(fraction: state.progress!.fraction),
          ],
          if (state is ConnectionFailed) ...[
            const SizedBox(height: Insets.xs),
            // The remedy, in full. A failure with its reason hidden behind a tap
            // is a failure the owner cannot act on.
            Text(
              state.failure.remedy,
              style: text.bodySmall?.copyWith(color: colors.ink2),
            ),
          ],
        ],
      ),
    );
  }
}

/// A live session's only mark. Accent, not green — see the library docstring.
class _StateDot extends StatelessWidget {
  const _StateDot({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: live ? colors.accent : colors.ink3,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    );
  }
}

/// A determinate bar, only ever fed a fraction the fetcher actually reported.
class _Progress extends StatelessWidget {
  const _Progress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 3,
        backgroundColor: colors.line2,
        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
      ),
    );
  }
}
