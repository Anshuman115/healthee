import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/shared/states/account_async_view.dart';

/// Works both inside a card and as a bounded screen body containing a ListView.
class CachedAsyncView<T> extends StatelessWidget {
  const CachedAsyncView({
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });
  final AsyncValue<ServerSnapshot<T>> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, T) builder;
  @override
  Widget build(BuildContext context) => AccountAsyncView<ServerSnapshot<T>>(
    value: value,
    onRetry: onRetry,
    builder: (context, snapshot) {
      if (!snapshot.stale) return builder(context, snapshot.data);
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: constraints.hasBoundedHeight
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            Text(
              'Saved ${snapshot.fetchedAt.toLocal()} · ${snapshot.refreshError ?? 'checking for updates…'}',
            ),
            if (snapshot.refreshError != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry refresh'),
              ),
            if (constraints.hasBoundedHeight)
              Expanded(child: builder(context, snapshot.data))
            else
              builder(context, snapshot.data),
          ],
        ),
      );
    },
  );
}
