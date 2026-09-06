/// `What changed?` — every settled challenge, in the prototype's shape.
///
/// One outcome is `ChallengeOutcomeCard`; this screen is the header, the list,
/// and the two ways on. The prototype's screen shows a single outcome because
/// its fixture holds one; the element is repeated for a list rather than a
/// second shape invented for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/detail_page.dart';

/// The prototype's own h1 and eyebrow.
const String kOutcomesTitle = 'What changed?';

/// Its eyebrow.
const String kOutcomesEyebrow = 'Your completed challenges';

/// The settled challenges, newest first.
class OutcomesScreen extends ConsumerWidget {
  /// Reads `challengeOutcomesProvider` and nothing else.
  const OutcomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToneScope(
      tone: Tone.movement,
      child: CachedAsyncView<List<ChallengeOutcome>>(
        value: ref.watch(challengeOutcomesProvider),
        onRetry: () => ref.invalidate(challengeOutcomesProvider),
        builder: (context, outcomes) => DetailPage(
          eyebrow: kOutcomesEyebrow,
          title: kOutcomesTitle,
          children: <Widget>[
            if (outcomes.isEmpty)
              const EmptyState(
                message: 'No completed evaluations yet',
                hint: 'Outcomes appear after the server settles a challenge.',
              )
            else
              for (var i = 0; i < outcomes.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: Insets.xxl),
                ChallengeOutcomeCard(outcome: outcomes[i]),
              ],
            const DataFooter(),
          ],
        ),
      ),
    );
  }
}
