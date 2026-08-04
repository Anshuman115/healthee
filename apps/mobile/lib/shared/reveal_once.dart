/// Charts animate **once** on first reveal, and never again on scroll-back.
///
/// ## The bug this exists to make impossible
///
/// `CLAUDE.md` names it as a hard rule and `docs/APP_DESIGN_BRIEF.md` §7 repeats
/// it: *"Scrollable chart screens use `ListView.builder` + reveal-once
/// animation, or charts replay on every scroll."* It is a known, expensive bug
/// in the legacy app, and the mechanism is worth stating because the obvious fix
/// does not work.
///
/// `ListView.builder` destroys an item's element when it scrolls out of view and
/// builds a fresh one when it comes back. So an animation held in the chart's
/// own `State` — a controller started in `initState` — restarts every single
/// time the chart re-enters the viewport. It looks like a nervous tic and it
/// costs a full repaint of every chart on every scroll, against a 60 fps budget.
///
/// The fix is that **"have I been seen?" is not the chart's state to hold.** It
/// belongs to something that outlives the item: a [RevealRegistry] owned by the
/// screen. The registry is a set of ids; the first `markSeen` for an id returns
/// true and the chart animates, and every rebuild after that returns false and
/// the chart paints its final frame immediately.
///
/// ## Why an explicit id rather than a key or a position
///
/// A list index is not an identity — insert a card at the top and every chart
/// below it "becomes" a different index and animates again. The id is the thing
/// the chart is *about* (`heart-rate-day`), so it survives reordering, and two
/// charts cannot collide by accident because a duplicate id is a visible one.
library;

import 'package:flutter/material.dart';

/// Remembers which reveals have already played. Owned by a screen, not a chart.
class RevealRegistry {
  final Set<Object> _seen = <Object>{};

  /// True the FIRST time [id] is asked about, false forever after.
  ///
  /// The whole contract in one method: a chart animates on a true and paints
  /// finished on a false, and the answer cannot change back because nothing
  /// removes from the set.
  bool markSeen(Object id) => _seen.add(id);

  /// Whether [id] has already been revealed. For tests and for debug output.
  bool hasSeen(Object id) => _seen.contains(id);

  /// Forgets everything, so the next build animates again.
  ///
  /// Exists for pull-to-refresh, where new data genuinely deserves the reveal.
  /// Nothing calls it on scroll, which is the point of the whole file.
  void reset() => _seen.clear();
}

/// Plays [builder]'s reveal once for [id], then paints it finished.
class RevealOnce extends StatefulWidget {
  /// [registry] must outlive this widget — a screen's `State`, never a local.
  const RevealOnce({
    required this.id,
    required this.registry,
    required this.builder,
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  /// What this reveal is about. Stable across rebuilds and reorderings.
  final Object id;

  /// Where "already seen" is remembered.
  final RevealRegistry registry;

  /// Draws the content at progress `t`, 0 → 1.
  final Widget Function(BuildContext context, double t) builder;

  /// How long the reveal takes.
  final Duration duration;

  /// Its easing.
  final Curve curve;

  @override
  State<RevealOnce> createState() => _RevealOnceState();
}

class _RevealOnceState extends State<RevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Asked exactly once, in initState, so a rebuild caused by anything else —
    // a theme change, a parent setState — cannot consume a fresh reveal.
    final first = widget.registry.markSeen(widget.id);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      // Already seen: start finished. Not "animate quickly" and not "skip the
      // first frame" — there is no animation at all, so scrolling a long list
      // costs no ticker and no repaint beyond the paint itself.
      value: first ? 0 : 1,
    );
    if (first) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    return AnimatedBuilder(
      animation: curved,
      // RepaintBoundary around anything that animates: without it the reveal
      // repaints the whole list item's layer on every frame (Standards §1).
      builder: (context, _) =>
          RepaintBoundary(child: widget.builder(context, curved.value)),
    );
  }
}
