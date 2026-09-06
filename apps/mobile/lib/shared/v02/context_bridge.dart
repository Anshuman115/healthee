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

class _BridgeText extends StatelessWidget {
  const _BridgeText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TypeScale.bridge.copyWith(color: context.colors.ink2),
  );
}
