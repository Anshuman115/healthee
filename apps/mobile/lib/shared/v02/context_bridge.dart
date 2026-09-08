/// `.context-bridge` — the left-rule connector between two panels.
///
/// ```css
/// .context-bridge        { position: relative; padding: 14px 4px 14px 26px;
///                          margin: 0 8px;
///                          border-bottom: 1px solid var(--line); }
/// .context-bridge::before{ content:''; width:1px; position:absolute;
///                          top:0; bottom:0; left:8px; background:var(--line); }
/// .context-bridge::after { content:''; width:5px; height:5px;
///                          border-radius:50%; background:var(--family);
///                          position:absolute; left:6px; top:23px; }
/// .context-bridge p      { font-size: 11px; line-height: 1.8; }
/// ```
///
/// Two pseudo-elements, so two `Positioned` children in a `Stack`: a full-height
/// hairline at x = 8, and a 5 px family dot at x = 6, y = 23 — the dot straddles
/// the rule and marks where the sentence begins. `margin: 0 8px` is baked in
/// rather than left to the caller, because the rule's `left: 8px` is measured
/// from the element's own box and the two numbers only line up together.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// A connective sentence, hung off a vertical rule.
class ContextBridge extends StatelessWidget {
  /// Builds a bridge around [child], usually a `Text`.
  const ContextBridge({required this.child, super.key});

  /// Builds a bridge carrying one sentence, styled as `.context-bridge p`.
  ContextBridge.text(String text, {super.key})
    : child = _BridgeText(text: text);

  /// `H.bridge(tone, copy, route, label)` — the sentence **and** the link that
  /// ends it.
  ///
  /// Every bridge in the prototype has one: `<p>${copy} <a href="#${route}">
  /// ${label} ${arrow}</a></p>`. It is the same paragraph, so the label sits
  /// inline at the end of the sentence rather than on a line of its own — a
  /// bridge is one thought, and a control under it would read as a second.
  ///
  /// [onOpen] of null draws the sentence alone: a bridge whose destination does
  /// not exist yet must not advertise one.
  ContextBridge.link(
    String text, {
    required String label,
    VoidCallback? onOpen,
    super.key,
  }) : child = onOpen == null
           ? _BridgeText(text: text)
           : _BridgeLink(text: text, label: label, onOpen: onOpen);

  /// `margin: 0 8px`.
  static const double margin = 8;

  /// `padding: 14px 4px 14px 26px`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(26, 14, 4, 14);

  /// `::before { left: 8px; width: 1px }`.
  static const double ruleLeft = 8;

  /// `::after { width: 5px; height: 5px }`.
  static const double dotSize = 5;

  /// `::after { left: 6px }`.
  static const double dotLeft = 6;

  /// `::after { top: 23px }`.
  static const double dotTop = 23;

  /// The bridge's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: margin),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: ruleLeft,
            top: 0,
            bottom: 0,
            width: hairline,
            child: ColoredBox(color: colors.line),
          ),
          Positioned(
            left: dotLeft,
            top: dotTop,
            width: dotSize,
            height: dotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.family,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.line, width: hairline),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The sentence with its trailing link, as one wrapping paragraph.
class _BridgeLink extends StatelessWidget {
  const _BridgeLink({
    required this.text,
    required this.label,
    required this.onOpen,
  });

  /// `H.icon('arrow','small')` — the glyph the prototype ends the link with.
  static const double arrowSize = 12;

  final String text;
  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TypeScale.bridge;
    return Text.rich(
      TextSpan(
        style: style.copyWith(color: colors.ink2),
        children: <InlineSpan>[
          TextSpan(text: '$text '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                onTap: onOpen,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: TypeScale.textButton.copyWith(
                        color: context.family,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: arrowSize,
                      color: context.family,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeText extends StatelessWidget {
  const _BridgeText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TypeScale.bridge.copyWith(color: context.colors.ink2),
  );
}
