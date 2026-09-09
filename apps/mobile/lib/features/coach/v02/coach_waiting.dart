/// What the owner looks at while the coach thinks — for up to five minutes.
///
/// It replaced `LoadingState(label: 'Asking your coach')`: one 16 px spinner and
/// four words, held for a wait that was **measured at 80–304 seconds** on the
/// owner's own broad question. A spinner is a fine way to say "a moment"; held
/// for four minutes it says "this has hung", and the owner's own report was that
/// the coach "takes insane amount of time" — which was true, and the screen was
/// doing nothing to make the time legible.
///
/// ## Why there is no stepper here
///
/// The obvious design is a checklist that lights up: *reading your sleep* →
/// *checking the research* → *writing*. It is the wrong design for this app,
/// because `POST /api/coach` is one synchronous request and **the app cannot
/// know which round the server is on**. A stepper advancing on a timer would be
/// inventing server state and showing it as fact — the exact move the honesty
/// contract exists to forbid, made harmless-looking by being decoration.
///
/// So what is shown is only what is actually known:
///
/// * the elapsed time, counted here and true by construction;
/// * a description of the whole operation, in the present tense but never
///   claiming a stage — it reads "reading your data and the graded research",
///   which is what the turn does end to end;
/// * after [_longAfter], a second sentence saying the wait is longer than usual
///   and that broad questions take more rounds. That is a statement about the
///   distribution, not about this request, and it is the honest way to say
///   "still working" without pretending to know why.
///
/// Real per-stage progress is available and is not a UI change: the server would
/// have to stream its tool calls (`insights/coach.py::_loop` already names each
/// one). Until it does, this file's job is to be truthful about not knowing.
///
/// ## "You can leave this screen"
///
/// The one piece of genuinely useful news, and it is checked rather than hoped:
/// `CoachController` is `@Riverpod(keepAlive: true)`, so the request is owned by
/// the provider and not by this widget. Popping the route does not cancel it and
/// the answer is in the thread on return. Told to the owner because a four-minute
/// wait they are required to sit through is a different product from one they can
/// walk away from.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// The panel shown while a question is in flight.
class CoachWaiting extends StatefulWidget {
  /// Builds the waiting state.
  const CoachWaiting({super.key});

  @override
  State<CoachWaiting> createState() => _CoachWaitingState();
}

/// When the wait stops being ordinary. The measured distribution on the owner's
/// own broad question was 80 · 82 · 132 · 169 · 277 · 304 s, so a minute is well
/// inside "normal" and saying so early would be crying wolf at the median.
const Duration _longAfter = Duration(seconds: 75);

class _CoachWaitingState extends State<CoachWaiting>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulse;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // One second is the coarsest tick that still reads as a live clock. Anything
    // finer would repaint sixty times a minute to move a digit that changes once.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool long = _elapsed >= _longAfter;
    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: hSquircle(
          Radii.card,
          side: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              FadeTransition(
                opacity: _pulse.drive(Tween<double>(begin: 0.35, end: 1)),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Your coach is working',
                  style: TypeScale.panelTitle.copyWith(color: colors.ink),
                ),
              ),
              Text(
                _clock(_elapsed),
                style: TypeScale.panelUnit.copyWith(
                  color: colors.ink3,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Reading your own data and the graded research, then writing an '
            'answer that cites both.',
            style: TypeScale.panelNote.copyWith(color: colors.ink2),
          ),
          if (long) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              'This is taking longer than most questions. Broad questions need '
              'more rounds — it has not failed.',
              style: TypeScale.panelNote.copyWith(color: colors.ink2),
            ),
          ],
          const SizedBox(height: Insets.md),
          Text(
            'You can leave this screen. The answer will be here when you come '
            'back.',
            style: TypeScale.panelNote.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}

/// Elapsed time as `m:ss`, or `s` under a minute.
///
/// Public for the test, which asserts the format rather than pumping a clock:
/// the thing worth pinning is that a four-minute wait reads as `4:03` and not as
/// `243` — the second is a number the owner has to convert before it means
/// anything, at the moment they are least inclined to.
String coachElapsedLabel(Duration elapsed) => _clock(elapsed);

String _clock(Duration elapsed) {
  final int seconds = elapsed.inSeconds;
  if (seconds < 60) {
    return '${seconds}s';
  }
  final String rest = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$rest';
}
