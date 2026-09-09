/// Openers built from the owner's OWN figures — the part legacy could not do.
///
/// The legacy coach offers four fixed questions: *"What should I do today?"*,
/// *"How's my sleep trending?"*, and two more. They are the same four for every
/// owner on every day, which makes them a menu rather than a conversation, and
/// on a product whose entire claim is that it speaks from your measurements they
/// are the one surface that speaks from none.
///
/// So an opener here names a number the app is already holding: "What should I
/// make of my sleep debt (29 h)?" rather than "How's my sleep trending?". The
/// figure comes from `TodaySnapshot`, which the screen already reads, so this
/// costs no request and no question.
///
/// ## The wording rule, which is the whole of the honesty here
///
/// **An opener states a figure and asks about it. It never says what the figure
/// means, which way it moved, or why.**
///
/// "Why did my sleep regularity fall to 65.7?" would be the obvious phrasing and
/// it is forbidden: it asserts a fall the app has not established here, and it
/// puts that assertion in the OWNER's mouth — the coach would then be answering a
/// premise it was handed rather than one it checked. `insights/coach_thread.py`
/// screens what arrives, but a question is not a claim to be screened; it is the
/// frame the answer is built on. So every template is neutral by construction:
/// "What should I make of X (value)?" and nothing that implies a direction.
///
/// A test asserts the banned words rather than trusting the templates, because
/// the next template will be written by somebody reading the list and not this
/// paragraph.
///
/// ## Absence is not filled
///
/// A `Reading` that is `Withheld` or `Excluded` yields no opener — the figure is
/// genuinely not there, and an opener naming it would be the app inventing a
/// number to look personal. When fewer than [_wanted] survive, the generic
/// questions fill the rest, in their own order, never duplicated.
library;

import 'package:healthee/data/models/today_snapshot.dart';

/// The fallbacks, in the prototype's order and wording.
const List<String> kGenericOpeners = <String>[
  'What should I notice about my sleep?',
  'How is activity affecting my recovery?',
  'What does my HRV mean?',
];

/// How many openers the screen shows.
const int _wanted = 3;

/// Openers for [snapshot], most specific first, padded with the generic ones.
///
/// Never returns more than [_wanted], never returns a duplicate, and never
/// returns an empty list — a screen with no openers at all would be a worse
/// answer than three general ones.
List<String> coachOpeners(TodaySnapshot? snapshot) {
  final grounded = <String>[
    if (_sleepDebt(snapshot) case final String opener) opener,
    if (_regularity(snapshot) case final String opener) opener,
    if (_recovery(snapshot) case final String opener) opener,
  ];
  final openers = <String>[...grounded];
  for (final generic in kGenericOpeners) {
    if (openers.length >= _wanted) {
      break;
    }
    if (!openers.contains(generic)) {
      openers.add(generic);
    }
  }
  return openers.take(_wanted).toList(growable: false);
}

/// "…my sleep debt (29 h)?" — rounded to the hour, because the owner's debt is
/// a rolling estimate and printing it to the minute would claim a precision the
/// figure does not carry.
String? _sleepDebt(TodaySnapshot? snapshot) {
  final debt = snapshot?.sleepDebt.valueOrNull;
  if (debt == null || debt.debtMin < 60) {
    return null;
  }
  return 'What should I make of my sleep debt (${(debt.debtMin / 60).round()} h)?';
}

/// "…my sleep regularity (65.7)?" — the SRI, unitless by definition.
String? _regularity(TodaySnapshot? snapshot) {
  final sri = snapshot?.sleepHealth.valueOrNull?.sri;
  if (sri == null) {
    return null;
  }
  return 'What should I make of my sleep regularity (${sri.toStringAsFixed(1)})?';
}

/// "…my recovery score (83)?" — the band is deliberately not named. "Your
/// recovery is good, what should I do?" would hand the coach a judgement to
/// agree with instead of a number to read.
String? _recovery(TodaySnapshot? snapshot) {
  final recovery = snapshot?.recovery.valueOrNull;
  if (recovery == null) {
    return null;
  }
  return 'What should I make of my recovery score (${recovery.recovery})?';
}
