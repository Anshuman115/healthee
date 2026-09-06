import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/features/gps/route_explorer.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = recordedRouteProvider(id);
    return Scaffold(
      appBar: AppBar(title: const Text('Recorded route')),
      body: AccountAsyncView<RecordedRoute>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        builder: (context, route) {
          final sections = [
            RouteExplorer(points: route.points),
            _summary(route),
          ];
          return ListView.separated(
            padding: const EdgeInsets.all(Insets.lg),
            itemCount: sections.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: Insets.lg),
            itemBuilder: (context, index) => sections[index],
          );
        },
      ),
    );
  }

  Widget _summary(RecordedRoute route) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${route.start.toLocal()}'),
        if (route.distanceKm != null) Text('${route.distanceKm} km'),
        if (route.durationS != null)
          Text('Duration: ${durationLabel(route.durationS! ~/ 60)}'),
        if (route.movingS != null)
          Text('Moving: ${durationLabel(route.movingS! ~/ 60)}'),
        if (route.avgPaceMinKm != null)
          Text('Average pace: ${route.avgPaceMinKm} min/km'),
        if (route.avgHr != null) Text('Average HR: ${route.avgHr} bpm'),
        if (route.maxHr != null) Text('Maximum HR: ${route.maxHr} bpm'),
        if (route.elevationMinM != null)
          Text('Minimum elevation: ${route.elevationMinM} m'),
        if (route.elevationMaxM != null)
          Text('Maximum elevation: ${route.elevationMaxM} m'),
        if (route.elevationGainM != null)
          Text('Elevation gain: ${route.elevationGainM} m'),
        if (route.elevationLossM != null)
          Text('Elevation loss: ${route.elevationLossM} m'),
        if (route.vo2max != null)
          Text(
            'Session VO₂max estimate: ${route.vo2max} ml/kg/min · ${route.vo2Method ?? 'method unavailable'}',
          )
        else
          const Text(
            'No VO₂max estimate for this route. The server requires suitable GPS and heart-rate data.',
          ),
        if (route.r2 != null)
          Text(
            'Model fit r²: ${route.r2}. Fit does not establish measurement accuracy.',
          ),
      ],
    ),
  );
}
