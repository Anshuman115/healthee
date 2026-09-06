import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/history/history_marker.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_chart.dart';
import 'package:healthee/shared/states/current_account_value.dart';

class HistoryExplorer extends ConsumerWidget {
  const HistoryExplorer({required this.points, required this.days, super.key});
  final List<TrendPoint> points;
  final int days;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = historyMarkersProvider(days);
    final value = currentAccountValue(ref.watch(provider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HistoryChart(points: points, markers: value.value ?? []),
        if (value.isLoading) const Text('Loading your log markers…'),
        if (value.hasError)
          TextButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Log markers unavailable · retry'),
          ),
        if (value.value?.isNotEmpty == true)
          ExpansionTile(
            title: const Text('Your logs in this period'),
            children: [
              SizedBox(
                height: 240,
                child: ListView.builder(
                  itemCount: value.value!.length,
                  itemBuilder: (context, index) {
                    final marker = value.value![index];
                    return ListTile(
                      title: Text('${marker.day} · ${marker.kind}'),
                      trailing: Text('${marker.count}'),
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}
