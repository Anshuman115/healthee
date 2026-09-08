/// The one thing that changes when a panel is half as wide.
///
/// `richer.css` does not define a second panel. It redefines six numbers when a
/// panel is inside `.twin-panels`:
///
/// ```css
/// .twin-panels .panel        { padding: 14px }
/// .twin-panels .panel-head   { margin-bottom: 8px }
/// .twin-panels .panel-title  { font-size: 11px; gap: 5px }
/// .twin-panels .panel-value  { font-size: 28px }
/// .twin-panels .panel-value>small { font-size: 10px }
/// .twin-panels .panel-note   { font-size: 10px; margin-top: 8px }
/// .twin-panels .panel-head .text-button { font-size: 0; … .icon 13px }
/// ```
///
/// That last rule is the interesting one: at half width the head's action loses
/// its **words** and keeps only its arrow. So this is a cascade, exactly like
/// `ToneScope` — the container declares it once and every part inside resolves
/// it — rather than a `compact: true` flag threaded through five constructors.
/// A flag passed by hand is a flag that gets passed to four of the five.
library;

import 'package:flutter/widgets.dart';

/// How much room a panel has.
enum PanelDensityLevel {
  /// A full-width panel: `richer.css`'s `.panel` rules, unqualified.
  normal,

  /// A panel sharing a row: the `.twin-panels .panel` overrides.
  compact,
}

/// Declares the density for every panel part beneath it.
class PanelDensity extends InheritedWidget {
  /// Wraps [child] at [level].
  const PanelDensity({required this.level, required super.child, super.key});

  /// The declared density.
  final PanelDensityLevel level;

  /// The nearest declared density, or [PanelDensityLevel.normal].
  static PanelDensityLevel of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PanelDensity>()
          ?.level ??
      PanelDensityLevel.normal;

  @override
  bool updateShouldNotify(PanelDensity oldWidget) => oldWidget.level != level;
}

/// Reads the cascade, the way `context.family` reads the tone's.
extension PanelDensityOf on BuildContext {
  /// Whether this point in the tree is inside a half-width panel.
  bool get compactPanel =>
      PanelDensity.of(this) == PanelDensityLevel.compact;
}
