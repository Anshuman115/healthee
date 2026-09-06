/// The frame every pushed v02 screen shares: no app bar, a `.page-header.detail`
/// inside the scroll, and the page's own padding.
///
/// `richer.css`: `#main { padding: 20px 16px 112px }`. The app's own rung for the
/// same measure is `Insets.lg` / `Insets.xxl`, which is what `InstrumentScreen`
/// spends and therefore what a pushed screen spends too — one page rhythm, not
/// two.
///
/// **No `AppBar`.** `instrument_screen.dart` argues it for the tabs and the same
/// argument holds here: the prototype's detail screens open with their own back
/// control and a 23 px title inside the scroll, and a Material bar above that
/// would be the screen's name twice and 56 px spent on the second one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/shared/v02/screen_head.dart';

/// A pushed screen: head, body, footer, all in one scroll.
class DetailPage extends StatelessWidget {
  /// [children] are laid out in order under the head, with no gap of their own —
  /// each decides the space beneath it, as `SectionList` does for a tab.
  const DetailPage({
    required this.title,
    required this.children,
    this.eyebrow,
    super.key,
  });

  /// The screen's name.
  final String title;

  /// The line above it.
  final String? eyebrow;

  /// The body.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.xxl,
          ),
          children: <Widget>[
            DetailHead(
              title: title,
              eyebrow: eyebrow,
              onBack: Navigator.of(context).canPop()
                  ? Navigator.of(context).pop
                  : null,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
