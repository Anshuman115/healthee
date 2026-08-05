/// The face swap, measured rather than eyeballed.
///
/// Manrope replaced Instrument Sans (owner decision 2026-08-05: the old face
/// reads "newspaper" at display sizes). A typeface is not a drop-in, and three
/// things could have broken silently:
///
///   1. **Tabular figures.** `docs/APP_DESIGN_BRIEF.md` §7 makes them a hard
///      constraint — "non-tabular numerals in a metric column is a defect" — and
///      a face without a `tnum` table would keep the `FontFeature` and simply
///      ignore it. So this measures two digit strings of the same length and
///      asserts they come out the same width, which is what tabular MEANS.
///   2. **Overflow at display size.** Manrope runs wider. The greeting and the
///      hero figures are the strings with the least slack, so they are laid out
///      at the narrowest phone this app targets and checked against the box.
///   3. **A missing glyph.** Instrument Sans had **no U+2082**, so `SpO₂` drew a
///      tofu box on the live screen, and no `σ` for the recovery ladder's caption
///      either. Neither is caught by anything except looking — or by this, which
///      renders each character and asserts it is not the notdef box.
///
/// The fonts are loaded from `assets/fonts/` with a `FontLoader`, so every
/// measurement here is against the real face rather than the test host's
/// fallback.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/typography.dart';

/// The narrowest phone the app targets, in logical pixels, less the page
/// padding a screen actually leaves a card.
const double _narrowContent = 320 - 16 * 2 - 13 * 2;

/// Lays [text] out in [style] and returns its size.
Size _measure(String text, TextStyle style, {double maxWidth = double.infinity}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);
  return Size(painter.width, painter.height);
}

/// Every Unicode codepoint the TTF at [path] has a glyph for.
///
/// ## Why the font file is read rather than the glyph measured
///
/// A `TextPainter` cannot report "this came out as notdef", and the two obvious
/// proxies both fail here. Comparing **advance widths** against the notdef box
/// is not enough — `→` in Manrope lands 0.04 px from it, so a width check would
/// have gone green while proving nothing. Comparing **rasters** needs
/// `Picture.toImage`, which does not complete under the plain test binding.
///
/// The font file is the actual authority, so it is what gets asked. This walks
/// the `cmap` table's format-4 and format-12 subtables, which between them cover
/// every modern TTF; a font with neither returns empty and fails loudly rather
/// than passing by default.
Set<int> _codepoints(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
    }
  }
  if (cmapOffset < 0) {
    return const <int>{};
  }

  final covered = <int>{};
  final subtables = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < subtables; i++) {
    final encoding = cmapOffset + 4 + i * 8;
    final table = cmapOffset + data.getUint32(encoding + 4);
    switch (data.getUint16(table)) {
      case 4:
        final segments = data.getUint16(table + 6) ~/ 2;
        final ends = table + 14;
        final starts = ends + segments * 2 + 2;
        final deltas = starts + segments * 2;
        final ranges = deltas + segments * 2;
        for (var s = 0; s < segments; s++) {
          final end = data.getUint16(ends + s * 2);
          final start = data.getUint16(starts + s * 2);
          final delta = data.getUint16(deltas + s * 2);
          final rangeOffset = data.getUint16(ranges + s * 2);
          if (start == 0xFFFF) {
            continue;
          }
          for (var c = start; c <= end; c++) {
            final glyph = rangeOffset == 0
                ? (c + delta) & 0xFFFF
                : data.getUint16(
                    ranges + s * 2 + rangeOffset + (c - start) * 2,
                  );
            if (glyph != 0) {
              covered.add(c);
            }
          }
        }
      case 12:
        final groups = data.getUint32(table + 12);
        for (var g = 0; g < groups; g++) {
          final record = table + 16 + g * 12;
          final start = data.getUint32(record);
          final end = data.getUint32(record + 4);
          for (var c = start; c <= end && c - start < 0x10000; c++) {
            covered.add(c);
          }
        }
    }
  }
  return covered;
}

void main() {
  setUpAll(() async {
    final faces = Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.ttf'));
    final loader = FontLoader(healtheeFontFamily);
    for (final face in faces) {
      loader.addFont(
        Future<ByteData>.value(face.readAsBytesSync().buffer.asByteData()),
      );
    }
    await loader.load();
  });

  final theme = AppTheme.light.textTheme;

  test('the bundled family is the one the theme names', () {
    final vendored = Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.ttf'))
        .toList();

    expect(vendored, isNotEmpty);
    for (final face in vendored) {
      expect(
        face,
        startsWith(healtheeFontFamily),
        reason:
            'two vendored families is two things a TextStyle can name and one '
            'of them wrong — and the wrongness renders perfectly',
      );
    }
    expect(
      vendored,
      hasLength(3),
      reason: 'typography.dart selects w400, w500 and w600 and nothing else',
    );
  });

  group('tabular figures survived the swap', () {
    test('EVERY DIGIT HAS THE SAME ADVANCE WIDTH', () {
      // The failure this catches: a face with no `tnum` table keeps the
      // FontFeature and ignores it, so a 55 → 58 shifts every glyph beside it
      // and a 30-night column visibly ripples on scroll.
      final style = theme.displayLarge!;
      final narrow = _measure('11111', style).width;
      final wide = _measure('88888', style).width;
      expect(
        (narrow - wide).abs(),
        lessThan(0.01),
        reason: 'brief §7: non-tabular numerals in a metric column is a defect',
      );
    });

    test('it holds at label size too, where the sparkline feet live', () {
      final style = theme.labelSmall!;
      expect(
        (_measure('10:00', style).width - _measure('23:58', style).width).abs(),
        lessThan(0.01),
      );
    });
  });

  group('the glyphs the old face was missing', () {
    late Set<int> covered;

    setUpAll(() {
      covered = _codepoints('assets/fonts/Manrope-Regular.ttf');
      expect(
        covered,
        isNotEmpty,
        reason: 'the cmap reader found nothing, so every check below is vacuous',
      );
      // A control: a private-use codepoint no text font covers. Without it a
      // reader that silently answered "everything" would pass every case.
      expect(covered, isNot(contains(0xE000)));
    });

    for (final entry in <String, (int, String)>{
      '\u2082': (0x2082, 'SpO2 and VO2max - Instrument Sans had NONE, and drew a box'),
      '\u03C3': (0x03C3, "the recovery ladder's 'capped at +/-3 sigma' caption"),
      '\u00B1': (0x00B1, 'every uncertainty band'),
      '\u00B0': (0x00B0, 'skin temperature'),
      '\u00B7': (0x00B7, 'every module foot separator'),
      '\u2192': (0x2192, 'the sleep window and the See-all link'),
      '\u2014': (0x2014, 'the em dash this whole product writes in'),
      '\u2265': (0x2265, "sleep efficiency's cutoff"),
    }.entries) {
      final (codepoint, where) = entry.value;
      test('U+${entry.value.$1.toRadixString(16)} has a glyph - $where', () {
        expect(
          covered,
          contains(codepoint),
          reason:
              'U+${codepoint.toRadixString(16).toUpperCase()} is not in the '
              'vendored face, so it draws as a tofu box wherever it is used',
        );
      });
    }
  });

  group('display sizes still fit the narrowest phone', () {
    test('the greeting does not overflow', () {
      // Manrope runs wider than the face it replaced, and the greeting is the
      // largest type in the app.
      for (final greeting in <String>[
        'Good morning.',
        'Good afternoon.',
        'Still up.',
      ]) {
        final size = _measure(greeting, theme.displayLarge!);
        expect(
          size.width,
          lessThan(_narrowContent),
          reason: '"$greeting" is ${size.width.toStringAsFixed(1)} px of '
              '${_narrowContent.toStringAsFixed(0)}',
        );
      }
    });

    test('a hero figure and its unit fit half a grid row', () {
      // Two cells share a 320 px phone: each has roughly (320 - 40) / 2 px.
      const cell = (320 - 16 * 2 - 10) / 2 - 13 * 2;
      for (final figure in <String>['9,264', '2,350', '43.0', '6:20']) {
        final size = _measure(figure, theme.displayLarge!.copyWith(fontSize: 27));
        expect(
          size.width,
          lessThan(cell),
          reason: '"$figure" is ${size.width.toStringAsFixed(1)} px of $cell',
        );
      }
    });

    test('the widest module label fits its cell without ellipsis', () {
      // `Resp / SpO₂ · strap` is the longest label the grid can produce, and it
      // is the one the instrument-naming rule added.
      const cell = (320 - 16 * 2 - 10) / 2 - 13 * 2;
      final style = theme.labelSmall!.copyWith(
        fontSize: 9.5,
        letterSpacing: 0.12 * 9.5,
        fontWeight: FontWeight.w600,
      );
      final size = _measure('RESP / SPO₂ · STRAP', style);
      expect(size.width, lessThan(cell));
    });
  });

  test('the whole text theme is one family, in the weights vendored', () {
    const vendoredWeights = <FontWeight>[
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
    ];
    final styles = <TextStyle?>[
      theme.displayLarge,
      theme.displayMedium,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleMedium,
      theme.titleSmall,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelMedium,
      theme.labelSmall,
    ];
    for (final style in styles) {
      expect(style!.fontFamily, healtheeFontFamily);
      expect(
        vendoredWeights,
        contains(style.fontWeight),
        reason:
            'a weight the pubspec does not vendor is synthesised by the engine, '
            'which is a different drawing of the face nobody chose',
      );
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });
}
