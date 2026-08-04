/// What the protocol layer is doing right now, reported as it happens.
///
/// ## Why the protocol reports this instead of the UI guessing it
///
/// The screen needs to say "authenticating" while the handshake runs and
/// "connected" only once one has succeeded. There are two ways to get that, and
/// only one of them is honest.
///
/// The dishonest way is to infer it: set the label to "connecting", then to
/// "authenticating" after a plausible delay, then to "connected" when the future
/// returns. That produces a state machine that is *right about the outcome and
/// wrong about the present* — it shows "authenticating" during the radio
/// connect, and it shows nothing at all if a step takes an unusual length of
/// time. It is a progress bar that animates on a timer, which is the interface
/// version of a number nobody measured.
///
/// The honest way is the one below: the code that performs each step says when
/// it has reached it. `StrapSession.open` emits [StrapPhase.connecting] before
/// it opens the radio and [StrapPhase.authenticating] before the first
/// handshake frame goes out, and `StrapSync` emits one [StrapSyncProgress] per
/// fetch it starts. Nothing above the protocol invents a phase, so a screen
/// showing "authenticating" is showing that a handshake is genuinely in flight.
///
/// Both sinks are optional and synchronous void callbacks rather than streams.
/// A stream would need a subscription, a close, and a decision about buffering
/// on a path where dropping a progress tick is free and leaking a subscription
/// holds the radio.
library;

import 'package:meta/meta.dart';

/// A step of opening a session, emitted when the protocol reaches it.
enum StrapPhase {
  /// The radio is being opened. Nothing has been authenticated.
  connecting,

  /// The five-step handshake is in flight.
  authenticating,

  /// The handshake succeeded: there is a live, authenticated session.
  ///
  /// This is the ONLY thing that licenses a UI to say "connected", and it is
  /// emitted from inside `open()` after the strap accepted the proof — not from
  /// a caller that saw a future complete.
  authenticated,
}

/// Called by the session as it reaches each [StrapPhase].
typedef StrapPhaseSink = void Function(StrapPhase phase);

/// How far through the fetch plan one sync is.
@immutable
class StrapSyncProgress {
  /// [step] is 1-based and [total] is the whole plan, so `1 of 13` is the first.
  const StrapSyncProgress({
    required this.step,
    required this.total,
    required this.label,
  });

  /// Which step of the plan has just started, 1-based.
  final int step;

  /// How many steps the plan has in total.
  final int total;

  /// What is being fetched, in the owner's words — `heart rate`, `sleep`.
  final String label;

  /// 0–1, for a determinate bar. Reports the step that has STARTED, not one
  /// that has finished, so it never reads 100% while work is still running.
  double get fraction => total == 0 ? 0 : (step - 1) / total;

  @override
  String toString() => 'sync $step/$total: $label';
}

/// Called by the sync as it starts each step of the fetch plan.
typedef StrapProgressSink = void Function(StrapSyncProgress progress);
