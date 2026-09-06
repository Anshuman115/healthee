import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/gps/route_metric.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/shared/charts/day_line_chart.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Selectable route profiles; missing values are omitted, never replaced by zero.
class RouteProfiles extends StatelessWidget {
  const RouteProfiles({required this.points, required this.metric, super.key});
  final List<RoutePoint> points;
  final RouteMetric metric;
  @override
  Widget build(BuildContext context) {
    final data = <DevicePoint>[];
    final breakBefore = <DateTime>{};
    var gap = false;
    for (final point in points) {
      final value = metric.value(point);
      if (value == null) {
        gap = true;
        continue;
      }
      if (gap) breakBefore.add(point.at);
      gap = false;
      data.add(DevicePoint(point.at, value));
    }

    return StateCard(
      child: Column(
        children: [
          if (data.isEmpty)
            const Text('No values for this profile')
          else
            DayLineChart(
              points: data,
              breakBefore: breakBefore,
              progress: 1,
              color: context.colors.accent,
            ),
          Text('${metric.label} · ${metric.unit}'),
          if (metric == RouteMetric.heartRate)
            const Text('Server-aligned HR may be interpolated.'),
          if (metric == RouteMetric.elevation)
            const Text(
              'Server elevation corrections are applied where available.',
            ),
        ],
      ),
    );
  }
}
