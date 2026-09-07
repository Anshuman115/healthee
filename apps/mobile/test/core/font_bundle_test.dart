/// **The bundle is what the app asks for** — the gate that was missing.
///
/// Its sibling `typography_test.dart` measures the *face*: tabular figures,
/// glyph coverage, overflow at display size. Every one of those questions is
/// about a font that IS being used. This file asks a question one step earlier
/// and, it turns out, the one that was actually wrong: **is the app being served
/// the face it named?**
///
/// It was not. `HType.number` is legacy's `HType.num` and asks for **w700**;
/// `pubspec.yaml` vendored 400, 500 and 600. Flutter does not fail on a weight
/// it does not have — it substitutes the nearest — so all 74 instrument readouts
/// in the app rendered at 600. Nothing errored, nothing warned, and the screen
/// looked entirely correct while every number on it was the wrong drawing.
///
/// The same class of miss put `FontStyle.italic` on three call sites that
/// rendered upright, because Flutter does not synthesise a slant for a bundled
/// family either. Both are *incomplete font swap*, not design.
///
/// ## Both sides are derived, deliberately
///
/// The weights the app asks for are read by scanning `lib/`; the weights it
/// bundles are read out of `pubspec.yaml`. A hardcoded list on either side would
/// have to be kept current by the same person who forgot to add the 700 — which
/// is precisely how the gap opened, and why it stayed open through a full port.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/typography.dart';

void main() {
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
      hasLength(_declaredWeights().length),
      reason: 'one .ttf per weight declared in pubspec.yaml, and no spares',
    );
  });

  test('EVERY WEIGHT THE APP ASKS FOR IS A WEIGHT THE BUNDLE HAS', () {
    final asked = _weightsAskedFor();
    final vendored = _declaredWeights();
    expect(asked, isNotEmpty);
    expect(
      asked.difference(vendored),
      isEmpty,
      reason:
          'these weights are named in lib/ and not vendored, so Flutter is '
          'silently substituting the nearest face for them',
    );
    expect(
      vendored.difference(asked),
      isEmpty,
      reason: 'a vendored weight no style names is dead binary size',
    );
    // Named, because it is the one that was wrong: legacy's numerals are bold.
    expect(asked, contains(700));
    expect(vendored, contains(700));
  });

  test('NOTHING ASKS FOR AN ITALIC — Inter has no such face to give', () {
    // Not a deferred vendoring job: Inter's variable font carries a single
    // `wght` axis (200–800) and upstream publishes no italic companion —
    // measured off `Inter[wght].ttf`'s `fvar` table, not remembered. So the
    // app stopped asking, and this fails if it starts again.
    final asking = <String>[
      for (final file in _libSources())
        for (final line in file.readAsLinesSync())
          // Comments are excluded on purpose: `instrument_type.dart` explains
          // the removal at length and must be allowed to name what it removed.
          if (!line.trimLeft().startsWith('//') && line.contains('FontStyle.italic'))
            '${file.path}: ${line.trim()}',
    ];
    expect(
      asking,
      isEmpty,
      reason: 'an italic that renders upright is emphasis the reader never sees',
    );
    for (final style in _themeStyles()) {
      expect(style!.fontStyle ?? FontStyle.normal, FontStyle.normal);
    }
  });

  test('the whole text theme is one family, in the weights vendored', () {
    final vendored = _declaredWeights();
    for (final style in _themeStyles()) {
      expect(style!.fontFamily, healtheeFontFamily);
      expect(
        vendored,
        contains(style.fontWeight!.value),
        reason:
            'a weight the pubspec does not vendor is synthesised by the engine, '
            'which is a different drawing of the face nobody chose',
      );
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  test('HType asks for exactly the five roles’ weights, and gets them', () {
    // The five roles ported from legacy's `HType`, at legacy's own weights.
    // `number` is the one that was broken.
    final vendored = _declaredWeights();
    const ink = Color(0xFF000000);
    final roles = <String, TextStyle>{
      'serif': HType.serif(ink),
      'sans': HType.sans(ink),
      'number': HType.number(ink),
      'label': HType.label(ink),
      'eyebrow': HType.eyebrow(ink),
    };
    for (final role in roles.entries) {
      expect(
        vendored,
        contains(role.value.fontWeight!.value),
        reason: 'HType.${role.key} asks for a weight the bundle does not have',
      );
    }
    expect(roles['number']!.fontWeight, FontWeight.w700, reason: 'legacy’s num');
  });
}

/// The text-theme styles under test, in one place.
List<TextStyle?> _themeStyles() {
  final theme = healtheeTextTheme(
    ink: const Color(0xFF121217),
    ink2: const Color(0xFF56565F),
    ink3: const Color(0xFF6D6D7C),
  );
  return <TextStyle?>[
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
}

/// Every `.dart` file under `lib/`, generated ones excluded.
List<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => !file.path.endsWith('.g.dart'))
    .where((file) => !file.path.endsWith('.drift.dart'))
    .toList();

/// Every numeric weight named anywhere in `lib/`, read out of the source.
Set<int> _weightsAskedFor() {
  final pattern = RegExp(r'FontWeight\.w(\d{3})');
  return <int>{
    for (final file in _libSources())
      for (final match in pattern.allMatches(file.readAsStringSync()))
        int.parse(match.group(1)!),
  };
}

/// Every weight `pubspec.yaml` declares under the one font family.
Set<int> _declaredWeights() {
  final pattern = RegExp(r'^\s+weight:\s*(\d{3})\s*$', multiLine: true);
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final declared = <int>{
    for (final match in pattern.allMatches(pubspec)) int.parse(match.group(1)!),
  };
  expect(declared, isNotEmpty, reason: 'pubspec.yaml declares no font weights');
  return declared;
}
