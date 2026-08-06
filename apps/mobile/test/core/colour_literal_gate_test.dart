/// **Colour literals live in two files, and nowhere else.** This reads `lib/` and
/// proves it.
///
/// Engineering Standards §3: "Design tokens only — no inline `Color(0xFF…)` in
/// feature code." Until now that was a convention, held up by review and by the
/// fact that `palette.dart` was the only file with any hex in it. The stage
/// contrast repair added a second such file (`sleep_stage_palette.dart` — two
/// reasons to change, two files, Standards §1), and a convention that has just
/// gone from "one file" to "two files" is a convention on its way to "a few
/// files". So it is a gate now.
///
/// `flutter analyze` cannot see this: an inline `Color(0xFF3A7BD5)` in a widget
/// is valid Dart. Only a test that reads the source can.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only two files that may hold a colour literal.
const Set<String> _palettes = <String>{
  'lib/core/theme/palette.dart',
  'lib/core/theme/sleep_stage_palette.dart',
};

/// What a colour literal looks like in Dart. `Colors.red` is caught too: the
/// Material palette is a colour literal wearing a name, and using it would put a
/// value in the app that neither palette file chose.
///
/// **`Colors.transparent` is the one exemption**, and it is not a loophole: it
/// names no hue, so it cannot disagree with the palette. It is "draw nothing
/// here" — the same role `hole` plays for a missing number, and the same argument
/// that keeps `Colors.transparent` out of a palette file in the first place.
final RegExp _literal = RegExp(
  r'Color\(\s*0x|Color\.fromRGBO\(|Color\.fromARGB\(|\bColors\.(?!transparent\b)[a-z]',
);

void main() {
  test('no colour literal exists outside the two palette files', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      // Generated code is committed but its generator owns its style, exactly as
      // `analysis_options.yaml` excludes it from analysis.
      if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.drift.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      if (_palettes.contains(path)) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Doc comments and comments name these values constantly — the whole
        // argument for the stage repair is a table of hexes in a docstring.
        if (line.trimLeft().startsWith('//')) {
          continue;
        }
        if (_literal.hasMatch(line)) {
          offenders.add('$path:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'colour literals belong in $_palettes',
    );
  });

  test('MUTATION — the gate can actually see a literal', () {
    // A file-scanning test that finds nothing looks identical whether the rule
    // holds or the regex is broken. This proves the regex.
    expect(_literal.hasMatch('  color: const Color(0xFF3A7BD5),'), isTrue);
    expect(_literal.hasMatch('  color: Color.fromRGBO(1, 2, 3, 0.5),'), isTrue);
    expect(_literal.hasMatch('  color: Colors.redAccent,'), isTrue);
    expect(_literal.hasMatch('  color: context.colors.accent,'), isFalse);
    expect(_literal.hasMatch('  backgroundColor: Colors.transparent,'), isFalse);
  });

  test('both palette files exist — a rename must not silently widen the rule', () {
    for (final path in _palettes) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
