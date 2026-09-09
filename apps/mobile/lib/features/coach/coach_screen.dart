/// The coach, as a ROUTE — the prototype's own shape.
///
/// `screens-actions.js::H.screens.coach` is a full screen: `H.header(…, true)`
/// draws a back control, then `.coach-intro`, then the thread or the three
/// prompt buttons, then `.coach-form`, its `.form-note` and the data footer.
/// This app opened the same composition in a bottom sheet.
///
/// ## Why the sheet had to go rather than sit beside a route
///
/// **Five surfaces link here** — Today's entry card and its FAB, Insights,
/// `metric/:key`, the workout detail's *Discuss this workout* and the finding
/// detail's *Talk this through* — and the last two are asking about something
/// specific. A sheet cannot carry a subject in a location, cannot be deep
/// linked, and does not survive a rotation. Keeping both would be two ways in
/// with different back behaviour, which is the defect `router.dart` already
/// records one level up.
///
/// ## The topic is the OPENING MESSAGE, and now also a field
///
/// A caller's [topic] arrives as text already in the prototype's own
/// `.coach-form`, and the owner sends it. It is **not** asked automatically: a
/// question costs one of twenty per rolling thirty days, and a navigation that
/// spent one on arrival would be a charge nobody pressed anything for. That
/// half is unchanged, and it is the half the owner sees — the sentence is in
/// their input, in their words, editable or deletable before anything is sent.
///
/// `POST /api/coach` also takes an optional `topic` now, and [CoachBody] sends
/// it with every question asked from this screen. The two are different facts:
/// the seeded sentence is what the owner is ASKING, and the field is what
/// screen they came FROM, which the server could not otherwise know and which
/// it uses to rank its context and evidence. It is context and nothing else —
/// `insights/coach_thread.py` screens it with the refusal gate before any model
/// call and fences it in the prompt as a label rather than a finding, so the
/// app is not putting a claim in the server's mouth either.
///
/// ## The input cannot exist without the meter
///
/// This is the rule the whole file is built around, and it came here unchanged
/// from the sheet. A coach question costs one of twenty per rolling thirty days,
/// so the screen reads `/api/entitlement` first and **only builds an input when
/// it holds a balance that permits one**. There is no branch in which a text
/// field appears beside an unknown number: a checking state, a failed check, a
/// locked account and a spent window each render their own sentence and no box
/// to type in.
///
/// That is structural rather than careful — [CoachComposer] takes a non-null
/// remaining-or-uncapped decision as a required argument, so an input with no
/// meter behind it is not a widget this file can build. The **prompt buttons are
/// under the same rule**: a prompt asks a question, so it spends one, and
/// `CoachIntro` draws none when `onAsk` is null.
///
/// ## The meter is the server's, after every attempt
///
/// It is never decremented here. `coach_controller.dart` re-reads
/// `/api/entitlement` in a `finally`, because `routers/coach.py` refunds a
/// refusal, an unvalidated answer and a transport failure — a local subtraction
/// would be wrong in three of the five outcomes and wrong the flattering way
/// round. Nothing in this file subtracts anything.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:healthee/features/coach/coach_controller.dart';
import 'package:healthee/features/coach/v02/coach_composer.dart';
import 'package:healthee/features/coach/v02/coach_prompts.dart';
import 'package:healthee/features/coach/v02/coach_waiting.dart';
import 'package:healthee/features/coach/widgets/coach_meter.dart';
import 'package:healthee/features/coach/widgets/coach_thread.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/detail_page.dart';

// The cost-carrying label lives with the control that prints it. Re-exported so
// the screen stays the one import a caller — or a test pinning the wording —
// needs for this surface.
export 'package:healthee/features/coach/v02/coach_composer.dart'
    show CoachComposer, askLabel;

/// The prototype's own h1 and eyebrow for this surface.
const String kCoachTitle = 'Your coach.';

/// Its eyebrow.
const String kCoachEyebrow = 'A conversation with context';

/// `.form-note` — what an answer carries, said before one arrives.
const String kCoachFormNote =
    'Answers name the research notes behind them and the weakest grade among '
    'those notes. The coach says when it does not know.';

/// The coach conversation, its meter, and the input the meter licenses.
class CoachScreen extends ConsumerWidget {
  /// [topic] is an opening question a caller wants asked about a specific
  /// workout, finding or metric. [now] is injected by tests so "reopens in …"
  /// is deterministic.
  const CoachScreen({this.topic, this.now, super.key});

  /// The opening question, or null for the plain coach.
  final String? topic;

  /// The instant the reset countdown is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailPage(
      title: kCoachTitle,
      eyebrow: kCoachEyebrow,
      children: <Widget>[
        AsyncView<Entitlement>(
          value: ref.watch(coachEntitlementProvider),
          loadingLabel: 'Checking what your account includes',
          errorMessage: "Couldn't read what your account includes",
          onRetry: () => ref.invalidate(coachEntitlementProvider),
          builder: (context, entitlement) =>
              CoachBody(entitlement: entitlement, topic: topic, now: now),
        ),
        const DataFooter(),
      ],
    );
  }
}

/// Everything under the head: the meter, the thread, the opening, the input.
///
/// Public so a test can host it with an entitlement in hand rather than
/// scripting a client to produce one.
class CoachBody extends ConsumerWidget {
  /// [entitlement] is the freshly-read `/api/entitlement`.
  const CoachBody({required this.entitlement, this.topic, this.now, super.key});

  /// What the server says this owner holds.
  final Entitlement entitlement;

  /// The opening question a caller asked about, written into the input.
  final String? topic;

  /// The instant the reset countdown is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final conversation = ref.watch(coachControllerProvider);
    final allowance = entitlement.allowanceFor(kCoachFeature);
    // Uncapped means the feature is absent from PREMIUM_ALLOWANCE for a premium
    // owner — `api/gate.py`'s documented asymmetry, and the one case where a
    // missing meter is good news rather than an empty one.
    final uncapped = entitlement.premium && allowance == null;
    final canAsk = uncapped || (allowance?.hasRemaining ?? false);
    // [topic] rides with the question as well as seeding the input. Seeding it
    // puts the subject in the owner's own words, which is what they see and can
    // edit; SENDING it tells the server which screen this thread was opened
    // from, which is a different fact and one it could not otherwise have. It
    // goes on every ask from this screen, not only the first: the thread stays
    // the thread that was opened about that workout even after the owner edits
    // the opening sentence away. It is context and the server treats it as
    // context — screened by the refusal gate and fenced as a label, never a
    // claim (`insights/coach_thread.py`).
    void ask(String question) => unawaited(
      ref.read(coachControllerProvider.notifier).ask(question, topic: topic),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoachMeter(entitlement: entitlement, now: now),
        ),
        for (final entry in conversation.entries) CoachEntryView(entry: entry),
        _tail(
          started: !conversation.isEmpty,
          asking: conversation.asking,
          canAsk: canAsk,
        ),
        if (canAsk) ...<Widget>[
          CoachComposer(
            asking: conversation.asking,
            remaining: allowance?.remaining,
            // Only into an EMPTY thread. A topic re-seeded over a running
            // conversation would overwrite whatever the owner had half-typed
            // every time this screen rebuilt.
            initialQuestion: conversation.isEmpty ? topic : null,
            onAsk: ask,
          ),
        ],
        // The openers come AFTER the ask box, and only into an empty thread.
        // They are the fallback for an owner with nothing in mind, and a
        // fallback above the thing it stands in for is what pushed this
        // screen's actual purpose off the bottom of the phone.
        //
        // Kept on two lines exactly as it is: `test/mutations.sh` anchors a
        // guard on this call's `canAsk ? ask : null),` text, and a reflow
        // silently un-anchors it — the stale patch then runs the UNMUTATED
        // suite and reports a pass (HOW_WE_VERIFY section 2).
        if (conversation.isEmpty && !conversation.asking) ...<Widget>[
          const SizedBox(height: Insets.xl),
          // dart format off
          CoachPrompts(onAsk:
              canAsk ? ask : null),
          // dart format on
        ],
        if (canAsk) ...<Widget>[
          const SizedBox(height: Insets.lg),
          Text(
            kCoachFormNote,
            style: TypeScale.formNote.copyWith(color: colors.ink2),
          ),
        ],
        // Only once there is something to end. An empty thread offering to be
        // ended is a control that does nothing, and the prototype's coach opens
        // empty. See `CoachController.newThread` for why this exists at all.
        if (!conversation.isEmpty && !conversation.asking) ...<Widget>[
          const SizedBox(height: Insets.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: HLinkButton(
              label: 'Start a new thread',
              onPressed: ref.read(coachControllerProvider.notifier).newThread,
            ),
          ),
        ],
      ],
    );
  }

  /// What sits under the last entry: the spinner, the opening, or nothing.
  Widget _tail({
    required bool started,
    required bool asking,
    required bool canAsk,
  }) {
    if (asking) {
      // Not `LoadingState`: this wait was measured at 80-304 s, and a 16 px
      // spinner held for four minutes reads as a hang. `CoachWaiting` counts the
      // time it can actually see and says what it cannot. See that file.
      return const Padding(
        padding: EdgeInsets.only(top: Insets.md),
        child: CoachWaiting(),
      );
    }
    // The opening is what an EMPTY thread stands on. Once anything has been
    // asked it is gone, prompts included: three openers under a running
    // conversation are three more spends offered as decoration.
    if (started) {
      return const SizedBox.shrink();
    }
    // No permitting balance, no prompts — the same rule as the input, and the
    // card that replaces them carries the reason rather than leaving a dead box.
    // Nothing stands where the opening block used to.
    //
    // `.coach-intro` — a 56 pt symbol, "Let's make sense of your day." over two
    // lines at 26 pt, and a two-line paragraph — occupied roughly the first
    // THIRD of the owner's 2400 px screen and said nothing that screen did not
    // already say. The route header above it reads "A conversation with context /
    // Your coach."; the block under it repeated that in larger type and then
    // explained the product to someone already inside it.
    //
    // The legacy coach (`healthee-legacy/design_reference/.../v2-coach.png`) has
    // no such block: eyebrow, title, then CONTENT. It opens with something the
    // coach has actually said. We cannot open with that yet — the warm line the
    // nightly chain writes to `kv` is not served on any GET — and a headline is
    // not a substitute for it. An empty screen that gets out of the way is more
    // honest than filler that pretends to be content.
    return canAsk
        ? const SizedBox.shrink()
        : const EmptyState(
            message: 'No questions can be asked right now',
            hint:
                'The line above is your server’s own answer about this '
                'account, read just now. Nothing here has been spent.',
          );
  }
}
