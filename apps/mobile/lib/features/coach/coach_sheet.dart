/// The coach, as a bottom sheet off Today — not a tab.
///
/// **Legacy's shape.** `app/lib/main.dart:399` puts a `CoachFab` on Today and
/// nowhere else, and `app/lib/ui/coach_sheet.dart` opens a tall chat sheet from
/// it. The bar has five items and Coach is not among them; `core/tabs.dart` now
/// matches that, and the findings that were parked on a Coach tab have gone to
/// Insights, where they belong.
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
/// That is structural rather than careful — [_Composer] takes a non-null
/// [IncludedAllowance]-or-uncapped decision as a required argument, so an input
/// with no meter behind it is not a widget this file can build.
///
/// ## What is deliberately not here
///
/// Legacy's sheet persists forty conversations to the store and offers a history
/// list. Nothing in this app persists a conversation, so there is no history
/// button: a control over a list that dies with the process is a promise the
/// storage layer does not keep. The thread survives the sheet closing (the
/// controller is `keepAlive`) and no longer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:healthee/features/coach/coach_controller.dart';
import 'package:healthee/features/coach/widgets/coach_meter.dart';
import 'package:healthee/features/coach/widgets/coach_thread.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

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

  /// The instant the reset countdown is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Padding(
      // The keyboard AND the gesture inset: the sheet is presented on the root
      // navigator now, so it covers the tab bar that used to absorb the latter.
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.bg,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.card),
            ),
            side: BorderSide(color: colors.line, width: hairline),
          ),
        ),
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: [
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

class _SheetHead extends ConsumerWidget {
  const _SheetHead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final started = !ref.watch(coachControllerProvider).isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.sm, Insets.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coach', style: text.titleLarge),
                Text(
                  'Grounded in your own data and the research notes',
                  style: text.bodySmall?.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
          if (started)
            TextButton(
              onPressed: ref.read(coachControllerProvider.notifier).newThread,
              child: const Text('New'),
            ),
          IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.close),
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
    final conversation = ref.watch(coachControllerProvider);
    final allowance = entitlement.allowanceFor(kCoachFeature);
    // Uncapped means the feature is absent from PREMIUM_ALLOWANCE for a premium
    // owner — `api/gate.py`'s documented asymmetry, and the one case where a
    // missing meter is good news rather than an empty one.
    final uncapped = entitlement.premium && allowance == null;
    final canAsk = uncapped || (allowance?.hasRemaining ?? false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CoachMeter(entitlement: entitlement, now: now),
          ),
        ),
        const SizedBox(height: Insets.md),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.lg,
            ),
            itemCount: conversation.entries.length + 1,
            itemBuilder: (context, index) {
              if (index == conversation.entries.length) {
                return conversation.asking
                    ? const Padding(
                        padding: EdgeInsets.only(top: Insets.md),
                        child: LoadingState(label: 'Asking your coach'),
                      )
                    : _Opening(canAsk: canAsk);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: CoachEntryView(entry: conversation.entries[index]),
              );
            },
          ),
        ),
        if (canAsk)
          _Composer(
            asking: conversation.asking,
            remaining: allowance?.remaining,
            onAsk: (question) => unawaited(
              ref.read(coachControllerProvider.notifier).ask(question),
            ),
          ),
      ],
    );
  }
}

/// What the sheet says before anything has been asked.
class _Opening extends StatelessWidget {
  const _Opening({required this.canAsk});

  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    if (canAsk) {
      return const EmptyState(
        message: 'Ask about your own data',
        hint:
            'The coach reads your sleep, activity and recovery and answers from '
            'the research notes, citing every one it uses and stating the '
            'weakest grade among them. It will say when it does not know.',
      );
    }
    // No input is built in this state, so this card is the whole surface. It
    // must therefore carry the reason rather than leaving a dead box on screen.
    return const EmptyState(
      message: 'No questions can be asked right now',
      hint:
          'The line above is your server’s own answer about this account, read '
          'just now. Nothing here has been spent.',
    );
  }
}

/// The input. Only ever built with a balance that permits a question.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.asking,
    required this.remaining,
    required this.onAsk,
  });

  final bool asking;

  /// How many are left, or null when the account is uncapped.
  final int? remaining;

  final void Function(String question) onAsk;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final question = _controller.text.trim();
    if (question.isEmpty || widget.asking) {
      return;
    }
    _controller.clear();
    widget.onAsk(question);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line2, width: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            enabled: !widget.asking,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'Ask your coach…',
              isDense: true,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: widget.asking ? null : _send,
              // The cost is on the button, in the number, before the tap. A
              // meter at the top of a sheet and a bare "Send" at the bottom is
              // still a spend the owner has to remember to have read about.
              child: Text(askLabel(widget.remaining)),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the ask button says. Public so a test can pin the wording.
String askLabel(int? remaining) =>
    remaining == null ? 'Ask' : 'Ask — uses 1 of your $remaining';
