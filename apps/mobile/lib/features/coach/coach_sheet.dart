/// The coach, as a bottom sheet off Today — not a tab.
///
/// **Legacy's shape, and v02's contents.** `app/lib/main.dart:399` puts a
/// `CoachFab` on Today and nowhere else. The prototype draws the coach as a
/// screen (`screens-actions.js::H.screens.coach`); this app opens the same
/// composition in a sheet, because the sheet is where the entry point leads and
/// a modal over the app is what `shared/sheets/app_sheet.dart` exists to give.
/// Everything inside is the prototype's: the symbol, the heading, the three
/// prompts, the `.coach-message` bubbles and the `.coach-form`.
///
/// ## The input cannot exist without the meter
///
/// This is the rule the whole file is built around. A coach question costs one of
/// twenty per rolling thirty days, so the sheet reads `/api/entitlement` first and
/// **only builds an input when it holds a balance that permits one**. There is no
/// branch in which a text field appears beside an unknown number: a checking
/// state, a failed check, a locked account and a spent window each render their
/// own sentence and no box to type in.
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
import 'package:healthee/features/coach/v02/coach_intro.dart';
import 'package:healthee/features/coach/widgets/coach_meter.dart';
import 'package:healthee/features/coach/widgets/coach_thread.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

// The cost-carrying label lives with the control that prints it. Re-exported so
// the sheet stays the one import a caller — or a test pinning the wording —
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

/// Opens the coach sheet over the current screen.
Future<void> showCoachSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (context) => const CoachSheet(),
  );
}

/// The coach conversation, its meter, and the input the meter licenses.
class CoachSheet extends ConsumerWidget {
  /// [now] is injected by tests so "reopens in …" is deterministic.
  const CoachSheet({this.now, super.key});

  /// The sheet takes nine tenths of the app, as it always has.
  static const double heightFactor = 0.9;

  /// The instant the reset countdown is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Padding(
      // The keyboard AND the gesture inset: the sheet is presented on the root
      // navigator, so it covers the tab bar that used to absorb the latter.
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border(top: BorderSide(color: colors.line, width: hairline)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Column(
            children: <Widget>[
              const _SheetHead(),
              Expanded(
                child: AsyncView<Entitlement>(
                  value: ref.watch(coachEntitlementProvider),
                  loadingLabel: 'Checking what your account includes',
                  errorMessage: "Couldn't read what your account includes",
                  onRetry: () => ref.invalidate(coachEntitlementProvider),
                  builder: (context, entitlement) =>
                      _Body(entitlement: entitlement, now: now),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.page-header.detail`, in the sheet: the eyebrow, the title, and the controls.
class _SheetHead extends ConsumerWidget {
  const _SheetHead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final started = !ref.watch(coachControllerProvider).isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.md,
        Insets.sm,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  kCoachEyebrow,
                  style: TypeScale.pageDate.copyWith(color: colors.ink2),
                ),
                const SizedBox(height: 5),
                Text(
                  kCoachTitle,
                  style: TypeScale.detailTitle.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
          if (started)
            TextButton(
              onPressed: ref.read(coachControllerProvider.notifier).newThread,
              child: Text(
                'New',
                style: TypeScale.textLink.copyWith(color: colors.accent),
              ),
            ),
          IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.close),
            color: colors.ink,
            tooltip: 'Close the coach',
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.entitlement, required this.now});

  final Entitlement entitlement;
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
    void ask(String question) => unawaited(
      ref.read(coachControllerProvider.notifier).ask(question),
    );
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CoachMeter(entitlement: entitlement, now: now),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              0,
              Insets.xl,
              Insets.lg,
            ),
            itemCount: conversation.entries.length + 1,
            itemBuilder: (context, index) {
              if (index == conversation.entries.length) {
                return _tail(
                  started: !conversation.isEmpty,
                  asking: conversation.asking,
                  canAsk: canAsk,
                  ask: ask,
                );
              }
              return CoachEntryView(entry: conversation.entries[index]);
            },
          ),
        ),
        if (canAsk)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              0,
              Insets.xl,
              Insets.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CoachComposer(
                  asking: conversation.asking,
                  remaining: allowance?.remaining,
                  onAsk: ask,
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  kCoachFormNote,
                  style: TypeScale.formNote.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// What sits under the last entry: the spinner, the opening, or nothing.
  Widget _tail({
    required bool started,
    required bool asking,
    required bool canAsk,
    required void Function(String question) ask,
  }) {
    if (asking) {
      return const Padding(
        padding: EdgeInsets.only(top: Insets.md),
        child: LoadingState(label: 'Asking your coach'),
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
    return canAsk
        ? CoachIntro(onAsk: ask)
        : const Column(
            children: <Widget>[
              CoachIntro(onAsk: null),
              EmptyState(
                message: 'No questions can be asked right now',
                hint:
                    'The line above is your server’s own answer about this '
                    'account, read just now. Nothing here has been spent.',
              ),
            ],
          );
  }
}
