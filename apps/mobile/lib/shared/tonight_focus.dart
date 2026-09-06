import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/grounded_text.dart';

/// Today's compact view of the same server-selected focus shown on Sleep.
class TonightFocus extends ConsumerWidget {
  const TonightFocus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AccountAsyncView<SleepConsistency>(
    value: ref.watch(sleepConsistencyProvider),
    onRetry: () => ref.invalidate(sleepConsistencyProvider),
    builder: (context, consistency) {
      final lever = consistency.tonight;
      if (lever == null) return const SizedBox.shrink();
      return Card(child: ListTile(
        title: Text('Tonight · ${lever.title}'),
        subtitle: GroundedProse(text: lever.prose),
        trailing: lever.targetClock == null ? null : Text(lever.targetClock!),
        onTap: () => unawaited(context.push(Routes.sleep)),
      ));
    },
  );
}
