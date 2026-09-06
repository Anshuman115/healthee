import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/gps/route_metric.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Standard map tiles with the owner's recorded route and visible attribution.
class RouteMap extends StatelessWidget {
  const RouteMap({required this.points, required this.metric, super.key});
  final List<RoutePoint> points;
  final RouteMetric metric;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Text('No route coordinates');
    final sampled = mapPoints(points);
    final values = sampled.map(metric.value).nonNulls.toList()..sort();
    final coordinates = sampled
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(coordinates);
    final hasSpan = bounds.north != bounds.south || bounds.east != bounds.west;
    return SizedBox(
      height: 320,
      child: RepaintBoundary(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: coordinates.first,
            initialZoom: 15,
            initialCameraFit: hasSpan
                ? CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(24),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'codes.afk.healthee',
            ),
            PolylineLayer(
              polylines: [
                for (var i = 1; i < coordinates.length; i++)
                  Polyline(
                    points: [coordinates[i - 1], coordinates[i]],
                    strokeWidth: 4,
                    color: _color(context, metric.value(sampled[i]), values),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: coordinates.first,
                  child: const Icon(Icons.trip_origin, semanticLabel: 'Start'),
                ),
                Marker(
                  point: coordinates.last,
                  child: const Icon(Icons.flag, semanticLabel: 'Finish'),
                ),
              ],
            ),
            SimpleAttributionWidget(
              source: const Text('© OpenStreetMap contributors'),
              onTap: () => unawaited(
                _openAttribution(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttribution(BuildContext context) async {
    try {
      if (!await launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))) {
        throw const FormatException('No app could open map attribution');
      }
    } on Exception catch (error, stack) {
      AppLog.failure('gps', 'opening map attribution', error, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open map attribution. Try again after checking your browser.'),
        ));
      }
    }
  }

  Color _color(BuildContext context, double? value, List<double> values) {
    if (value == null || values.isEmpty) return context.colors.ink3;
    final low = values.first, high = values.last;
    final fraction = high == low
        ? 0.5
        : ((value - low) / (high - low)).clamp(0.0, 1.0);
    return Color.lerp(context.colors.ink3, context.colors.accent, fraction)!;
  }
}
