/// `.theme-options` — Light · Dark · System, as three tiles in a row.
///
/// ```css
/// .theme-options { display:grid; grid-template-columns:repeat(3,1fr);
///                  gap:12px; }
/// .theme-option  { padding:20px 4px; border:1px solid var(--rule);
///                  border-radius:16px; display:flex; flex-direction:column;
///                  gap:12px; align-items:center; font-size:12px; }
/// .theme-option[aria-pressed='true'] { border-color:var(--accent);
///                                      background:var(--accent-soft);
///                                      color:var(--accent); }
/// ```
///
/// ## The control holds no state of its own, and that is the whole point
///
/// `theme_setting.dart` records the rule this replaces the presentation of:
/// *"a `bool _dark` in either widget's `State` would have been a second copy of
/// a fact the app already has"*. So this widget is given [selected] and hands
/// back a tap; it never remembers which tile it drew. The header toggle and
/// this control both read and write `themeControllerProvider`, so choosing a
/// mode here moves the button and pressing the button moves this row — by
/// construction, not by being kept in step.
///
/// `aria-pressed` is a *pressed* state, not a checkbox: [Semantics.selected] is
/// its Flutter equivalent, and it is what a screen reader announces as "Dark,
/// selected".
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';

/// One tile of a [ThemeOptions] row.
@immutable
class ThemeOption<T> {
  /// [value] is what [ThemeOptions.onSelected] is called with.
  const ThemeOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  /// What choosing this tile means.
  final T value;

  /// Its glyph.
  final IconData icon;

  /// Its words.
  final String label;
}

/// A three-up picker. Stateless; see the library docstring.
class ThemeOptions<T> extends StatelessWidget {
  /// Builds the row. [selected] is drawn in the accent.
  const ThemeOptions({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// `.theme-options { gap: 12px }`.
  static const double gap = 12;

  /// `.theme-option { padding: 20px 4px }`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 20,
  );

  /// `border-radius: 16px`.
  static const double radius = 16;

  /// `.theme-option { gap: 12px }` — between the glyph and its word.
  static const double innerGap = 12;

  /// `.icon { width: 22px }`.
  static const double iconSize = 22;

  /// The tiles, in order.
  final List<ThemeOption<T>> options;

  /// Which one is current.
  final T selected;

  /// Called with a tile's value when it is tapped.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    // **`IntrinsicHeight` is not decoration.** `grid-template-columns` makes
    // every cell as tall as the tallest, and `CrossAxisAlignment.stretch` is
    // Flutter's equivalent — but stretch in a `Row` needs a bounded height, and
    // a row inside a scroll view has none. Without this the tiles were handed
    // `h = Infinity` and the whole screen failed to lay out. `TwinPanels`
    // solves the same CSS with the same widget.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < options.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              child: _Tile<T>(
                option: options[i],
                chosen: options[i].value == selected,
                onTap: () => onSelected(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tile. **Takes no `Color`** — see `tone_scope.dart`: a widget handed a
/// hue can be handed one that disagrees with the container it sits in, and
/// nothing catches it. It reads the four roles it needs from the active theme,
/// which is what every other primitive here does.
class _Tile<T> extends StatelessWidget {
  const _Tile({
    required this.option,
    required this.chosen,
    required this.onTap,
  });

  final ThemeOption<T> option;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mark = chosen ? colors.accent : colors.ink;
    return Semantics(
      button: true,
      selected: chosen,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: ThemeOptions.padding,
          decoration: BoxDecoration(
            color: chosen ? colors.accentSoft : null,
            border: Border.all(
              color: chosen ? colors.accent : colors.rule,
              width: hairline,
            ),
            borderRadius: BorderRadius.circular(ThemeOptions.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(option.icon, size: ThemeOptions.iconSize, color: mark),
              const SizedBox(height: ThemeOptions.innerGap),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FormType.themeOption.copyWith(color: mark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
