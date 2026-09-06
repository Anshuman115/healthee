import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/gps/gps_repository.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class LocalRoutes extends ConsumerWidget {
  const LocalRoutes({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AccountAsyncView<GpsRepository>(
    value: ref.watch(gpsRepositoryProvider),
    onRetry: () => ref.invalidate(gpsRepositoryProvider),
    builder: (context, repository) => AccountAsyncView<List<GpsRecordingRow>>(
      value: ref.watch(localGpsRecordingsProvider),
      onRetry: () => ref.invalidate(localGpsRecordingsProvider),
      builder: (context, rows) => Column(
        key: ObjectKey(repository),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved on this phone', style: Theme.of(context).textTheme.titleLarge),
          if (rows.isEmpty) const Text('No local recordings yet.'),
          for (final row in rows) _recording(context, ref, repository, row),
        ],
      ),
    ),
  );

  Widget _recording(BuildContext context, WidgetRef ref,
    GpsRepository repository, GpsRecordingRow row) => Card(child: Column(children: [
      ListTile(
        title: Text('${DateTime.fromMillisecondsSinceEpoch(row.startMs)}'),
        subtitle: Text('${row.status} · ${(row.distanceM / 1000).toStringAsFixed(2)} km'),
        trailing: row.status == 'uploaded'
          ? const Icon(Icons.map_outlined, semanticLabel: 'View uploaded route')
          : row.status == 'recording' ? const Icon(Icons.gps_fixed) : null,
        onTap: row.status == 'uploaded' ? () => unawaited(context.push(
          '${Routes.route}/${Uri.encodeComponent(row.id)}')) : null,
      ),
      if (row.status != 'recording' && row.status != 'uploaded')
        ServerActionButton(
          key: ValueKey(row.id), label: 'Upload',
          action: () => repository.upload(row.id),
          onSaved: () => ref.invalidate(recordedRoutesProvider),
        ),
    ]));
}
