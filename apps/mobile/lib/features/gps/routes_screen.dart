import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/data/gps/route_summary.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Saved routes'),
      actions: [
        IconButton(
          tooltip: 'Record a route',
          icon: const Icon(Icons.add_location_alt),
          onPressed: () => unawaited(context.push(Routes.gps)),
        ),
      ],
    ),
    body: AccountAsyncView<List<RouteSummary>>(
      value: ref.watch(recordedRoutesProvider),
      onRetry: () => ref.invalidate(recordedRoutesProvider),
      builder: (context, routes) => routes.isEmpty
          ? const Center(
              child: Text(
                'No uploaded routes yet. Record and upload an outdoor workout to see it here.',
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(recordedRoutesProvider.future),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return ListTile(
                    title: Text('${route.start.toLocal()}'),
                    subtitle: Text(
                      route.distanceKm == null
                          ? 'Distance unavailable'
                          : '${route.distanceKm} km',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(
                      context.push(
                        '${Routes.route}/${Uri.encodeComponent(route.id)}',
                      ),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}
