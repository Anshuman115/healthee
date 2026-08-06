/// The six instruments read while the owner was asleep.
///
/// **Legacy** `sleep_screen.dart:340–355` and `_vital` at 533. Two rows of three
/// equal cells, each a centred figure at `num(ink, 20, w700)` with its unit at
/// `num(ink3, 9)` on the baseline, then a 5 px coloured dot and the label at
/// `lbl(ink3, 8, 0.06)`. The hues are legacy's own per-cell choices.
///
/// ## The one change
///
/// Legacy drew `'—'` in any cell the strap did not measure, in the same ink as a
/// real reading. Every cell is a [Reading] here: a value renders as legacy's
/// figure, an absence renders as a hole its size, and [SleepGapNote] states at
/// the foot which cells are empty and why. Six absences for one reason are one
/// sentence, not six.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/instrument_module.dart';

/// Legacy's "Overnight vitals" module.
class OvernightVitalsCard extends StatelessWidget {
  /// [night] supplies all six readings.
  const OvernightVitalsCard({required this.night, super.key});

  /// The night that was measured.
  final SleepNight night;

  /// Slot name → reading, in the order legacy draws them. Also what
  /// [SleepGapNote] iterates, so a cell cannot go quiet without being named.
  Map<String, Reading<Object>> get slots => <String, Reading<Object>>{
    'Resting HR': night.restingHr,
    'HRV': night.hrvSleepAvg,
    'Breathing rate': night.respiratoryRate,
    'SpO₂': night.spo2Avg,
    'Lowest SpO₂': night.spo2Min,
    'Skin temperature': night.skinTempC,
  };

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    final colors = context.colors;
    return InstrumentModule(
      label: 'Overnight vitals',
      tag: null,
      minHeight: 0,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Vital(
              label: 'RESTING HR',
              reading: night.restingHr,
              format: _whole,
              unit: 'bpm',
              dot: hues.heart,
            ),
            _Vital(
              label: 'HRV',
              reading: night.hrvSleepAvg,
              format: _whole,
              unit: 'ms',
              dot: colors.accent,
            ),
            _Vital(
              label: 'RESP',
              reading: night.respiratoryRate,
              format: _whole,
              unit: 'br',
              dot: hues.respiratory,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            _Vital(
              label: 'SpO₂',
              reading: night.spo2Avg,
              format: _whole,
              unit: '%',
              dot: hues.spo2,
            ),
            _Vital(
              label: 'SpO₂ MIN',
              reading: night.spo2Min,
              format: _whole,
              unit: '%',
              dot: hues.spo2,
            ),
            _Vital(
              label: 'SKIN TEMP',
              reading: night.skinTempC,
              format: _tenth,
              unit: '°C',
              dot: hues.stress,
            ),
          ],
        ),
        SleepGapNote(fields: slots),
      ],
    );
  }

  static String _whole(double value) => value.round().toString();

  static String _tenth(double value) => value.toStringAsFixed(1);
}

/// One cell. Legacy's `_vital`.
class _Vital extends StatelessWidget {
  const _Vital({
    required this.label,
    required this.reading,
    required this.format,
    required this.unit,
    required this.dot,
  });

  final String label;
  final Reading<double> reading;
  final String Function(double value) format;
  final String unit;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              SleepFigure(
                reading: reading.map(format),
                style: HType.number(colors.ink, size: 20),
                holeWidth: 30,
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: HType.number(colors.ink3, size: 9, weight: FontWeight.w400),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HType.label(colors.ink3, size: 8, tracking: 0.06),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
