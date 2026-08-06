/// [Reading] — the type that makes the product's central promise a compiler rule.
///
/// ## The promise, and why a type is the only way to keep it
///
/// Healthee's one promise is that it never shows a number it cannot stand behind.
/// The server keeps its half structurally: when a gate refuses, `read/vo2max.py`
/// sets `estimate` to `null` **and** attaches a `withheld` block naming the reason
/// and the remedy. Its docstring states the paired contract in as many words —
/// *"the current-looking field itself must be `None` whenever this block is
/// present"* — because "a dated field the UI may not render does not undo a
/// confident current-looking number".
///
/// That last sentence is about **us**. The server can null the field; it cannot
/// make the app render the reason. If the app models a value as `double?`, then
/// forgetting the withheld case is not a bug the compiler can see — it is a blank
/// card, or worse, a dash where an explanation belonged. The gate would have been
/// defeated on the last hop, which is exactly how the VO₂max withhold was defeated
/// once already.
///
/// So the value and its honesty state are ONE type with four cases, and every
/// consumer must handle all four to compile.
///
/// ## Why a sealed union and not a nullable field with side-car flags
///
/// A `double? value` plus a `Withheld? withheld` plus a `List<Caveat> caveats` can
/// express states that cannot exist — a value *and* a withhold, a withhold with no
/// reason — and it lets a widget read `value` without ever looking at the rest.
/// Nothing fails; something is merely missing. A sealed union makes the illegal
/// states unrepresentable and, more importantly, makes the *omission* loud:
///
/// ```dart
/// // Add a fifth case to Reading and every switch like this stops compiling
/// // until someone decides what it should look like.
/// final widget = switch (reading) {
///   Present(:final value) => MetricValue(value),
///   Caveated(:final value, :final caveats) => MetricValue(value, caveats: caveats),
///   Withheld(:final withheld) => WithheldCard(withheld),
///   Excluded(:final exclusions) => ExcludedCard(exclusions),
/// };
/// ```
///
/// Dart's exhaustiveness checking on `sealed` types is a compile-time **error**,
/// not a lint, so this survives a reviewer having a bad day. That is the whole
/// design: correctness you cannot see by looking must be enforced by structure.
/// (`freezed` is not what provides this — the language is. See pubspec.yaml.)
///
/// ## The four cases are the server's own vocabulary
///
/// They are not invented here. `derive/freshness.py::caveat_block` fixes three of
/// them in a comment, and they are deliberately not interchangeable:
///
/// ```text
///   withheld   you could have this; here is the action that brings it back
///   excluded   nobody can price this, ever
///   caveats    this IS in your number, and here is which way it leans
/// ```
///
/// [Present] is the fourth: `data_confidence == 'ok'` with nothing attached.
///
/// The difference between [Withheld] and [Excluded] is the one a UI must never
/// blur, because it decides whether the owner is being shown a *task* or a *fact*.
/// "Log a weight and this comes back" is an action. "Sleep regularity cannot
/// honestly be converted into years" is a permanent property of the evidence, and
/// offering a retry button for it would be a lie about what we are able to do.
///
/// ## What this type is not
///
/// It is not a loading state and not an error state. Those belong to Riverpod's
/// `AsyncValue`, which wraps this one: `AsyncValue<Reading<T>>` reads as "the
/// request may still be in flight or have failed; if it succeeded, here is what
/// the server was willing to say". Folding them together would put "the network
/// timed out" and "we decline to estimate this" in the same case, and those are
/// opposite messages — one is our fault and worth retrying, the other is an answer.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:meta/meta.dart';

/// A value the server was willing to report, together with what it said about it.
///
/// Construct these only in the data layer — [package:healthee/data/honesty/envelope]
/// is the single site that folds a server payload into one.
@immutable
sealed class Reading<T extends Object> {
  /// Const so the whole model tree can be const-constructed (Standards §1).
  const Reading();

  /// The value if there is one, else null.
  ///
  /// A deliberate escape hatch for the narrow cases that genuinely do not care —
  /// a chart axis computing its own maximum, a cache deciding whether to store.
  /// **Not for rendering.** A widget that reaches for this has skipped the
  /// exhaustive switch and is back to the nullable field this type replaced;
  /// review it as such.
  T? get valueOrNull => switch (this) {
    Present<T>(:final value) => value,
    Caveated<T>(:final value) => value,
    Withheld<T>() => null,
    Excluded<T>() => null,
  };

  /// Whether a number reached the owner at all — true for [Present] and [Caveated].
  bool get hasValue => valueOrNull != null;

  /// What tilts the value, or an empty list when nothing does.
  ///
  /// The opposite of [valueOrNull]'s escape hatch, and it exists **for**
  /// rendering: a card that draws its own header — `InstrumentModule` and the
  /// tiles built on it — has to hand its disclosures somewhere, and reading them
  /// off the union means a caveated value cannot be drawn without them. Only
  /// [Caveated] has any; [Excluded]'s are a different claim (no value at all) and
  /// are deliberately not folded in here.
  List<Disclosure> get caveatsOrEmpty => switch (this) {
    Caveated<T>(:final caveats) => caveats,
    Present<T>() || Withheld<T>() || Excluded<T>() => const <Disclosure>[],
  };

  /// Applies [transform] to the value, carrying the honesty state through unchanged.
  ///
  /// Exists so a repository can convert units or reshape a payload without
  /// unwrapping and re-wrapping — the step where a caveat gets dropped.
  Reading<R> map<R extends Object>(R Function(T value) transform) => switch (this) {
    Present<T>(:final value) => Present<R>(transform(value)),
    Caveated<T>(:final value, :final caveats) => Caveated<R>(transform(value), caveats),
    Withheld<T>(:final disclosure) => Withheld<R>(disclosure),
    Excluded<T>(:final exclusions) => Excluded<R>(exclusions),
  };
}

/// The server reported a value and attached nothing to it (`data_confidence: ok`).
final class Present<T extends Object> extends Reading<T> {
  /// The reported value.
  const Present(this.value);

  /// The value, as the server sent it.
  final T value;

  @override
  bool operator ==(Object other) => other is Present<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Present<T>, value);

  @override
  String toString() => 'Present($value)';
}

/// The server reported a value **and** named which way it leans.
///
/// The number is real and is meant to be shown. The caveats travel with it and
/// must reach the surface that renders it: `caveat_block`'s docstring is explicit
/// that "a caveat only the database can see is the same silence somewhere new".
/// A UI that renders [Caveated] identically to [Present] has re-created that
/// silence — which is why they are separate cases rather than an empty list.
final class Caveated<T extends Object> extends Reading<T> {
  /// A reported value with at least one disclosure attached.
  const Caveated(this.value, this.caveats);

  /// The value, as the server sent it. Never null — that is the point.
  final T value;

  /// What tilts it, and by how much. Non-empty by construction; see
  /// [package:healthee/data/honesty/envelope].
  final List<Disclosure> caveats;

  @override
  bool operator ==(Object other) =>
      other is Caveated<T> &&
      other.value == value &&
      _sameDisclosures(other.caveats, caveats);

  @override
  int get hashCode => Object.hash(Caveated<T>, value, Object.hashAll(caveats));

  @override
  String toString() => 'Caveated($value, ${caveats.length} caveat(s))';
}

/// No value for today — and an action that would bring one back.
///
/// The remedy is the load-bearing half. `withheld_block` carries a `message`
/// written in the second person for exactly this reason, and a UI that renders
/// the reason id without the message has told the owner they are stuck.
final class Withheld<T extends Object> extends Reading<T> {
  /// A refusal, with its reason and its remedy.
  const Withheld(this.disclosure);

  /// Why there is no current value, what would restore it, and how old the last
  /// one was.
  final Disclosure disclosure;

  @override
  bool operator ==(Object other) => other is Withheld<T> && other.disclosure == disclosure;

  @override
  int get hashCode => Object.hash(Withheld<T>, disclosure);

  @override
  String toString() => 'Withheld(${disclosure.reason})';
}

/// No value, and no action would produce one — the evidence does not support it.
///
/// Distinct from [Withheld] because the owner can do nothing about it and must not
/// be invited to try. The biological-age payload's `excluded` list is the live
/// example: the SRI hazard "belongs to the software, not to the index", so
/// regularity is not converted into years at all. That is a statement about what
/// is knowable, and it renders as an explanation, never as a retry.
final class Excluded<T extends Object> extends Reading<T> {
  /// A permanent exclusion, with the reasoning behind it.
  const Excluded(this.exclusions);

  /// What was left out and why. Non-empty by construction.
  final List<Disclosure> exclusions;

  @override
  bool operator ==(Object other) =>
      other is Excluded<T> && _sameDisclosures(other.exclusions, exclusions);

  @override
  int get hashCode => Object.hash(Excluded<T>, Object.hashAll(exclusions));

  @override
  String toString() => 'Excluded(${exclusions.length} reason(s))';
}

bool _sameDisclosures(List<Disclosure> a, List<Disclosure> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
