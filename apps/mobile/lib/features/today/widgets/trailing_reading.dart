/// The figure in a module header's right-hand slot, or a hole where it belonged.
///
/// Legacy puts a bare figure there — `'${hrv?.round() ?? '—'} ms'`
/// (`today_screen.dart:250`) and `spo2 != null ? '${spo2.round()}%' : '—'`
/// (318). A dash in a header could mean zero, missing, or broken; a
/// [ValueHole.inline] at the same footprint means one thing, and the reason is
/// carried by the card that owns the metric.
///
/// Extracted on its second use (Standards §1) — the HRV module and the
/// blood-oxygen module both need it, and a second copy is a second chance for one
/// of them to print a dash.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// A header figure built from a [Reading].
class TrailingReading extends StatelessWidget {
  /// [format] turns the value into the exact string legacy prints.
  const TrailingReading({
    required this.reading,
    required this.format,
    required this.color,
    this.size = 13,
    this.weight = FontWeight.w700,
    super.key,
  });

  /// The value and its honesty state.
  final Reading<double> reading;

  /// `(v) => '${v.round()} ms'`.
  final String Function(double value) format;

  /// The metric's hue.
  final Color color;

  /// Point size of the figure.
  final double size;

  /// Its weight.
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final value = reading.valueOrNull;
    if (value == null) {
      // No reason here: a 20 px slot cannot carry one, and the module's own body
      // is where the metric's refusal is explained. The hole says only that the
      // number is deliberately absent.
      return const ValueHole.inline();
    }
    return Text(
      format(value),
      style: HType.number(color, size: size, weight: weight),
    );
  }
}
