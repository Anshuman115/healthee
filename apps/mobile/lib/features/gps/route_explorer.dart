import 'package:flutter/material.dart';
import 'package:healthee/data/gps/route_metric.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/features/gps/route_map.dart';
import 'package:healthee/features/gps/route_profiles.dart';

class RouteExplorer extends StatefulWidget {
  const RouteExplorer({required this.points, super.key});
  final List<RoutePoint> points;
  @override
  State<RouteExplorer> createState() => _RouteExplorerState();
}

class _RouteExplorerState extends State<RouteExplorer> {
  RouteMetric _metric = RouteMetric.elevation;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SegmentedButton<RouteMetric>(
        segments: [
          for (final metric in RouteMetric.values)
            ButtonSegment(value: metric, label: Text(metric.label)),
        ],
        selected: {_metric},
        onSelectionChanged: (value) => setState(() => _metric = value.single),
      ),
      RouteMap(points: widget.points, metric: _metric),
      const Text(
        'Color runs from lower to higher values; it is not a health judgement. Unmeasured values are gray.',
      ),
      if (widget.points.length > 2000)
        const Text(
          'Map uses up to 2,000 points for display. The saved track retains every point.',
        ),
      RouteProfiles(points: widget.points, metric: _metric),
    ],
  );
}
