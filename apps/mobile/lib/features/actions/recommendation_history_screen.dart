import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/recommendations/recommendation_history.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/shared/recommendation_entry.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class RecommendationHistoryScreen extends ConsumerStatefulWidget {
  const RecommendationHistoryScreen({super.key});
  @override
  ConsumerState<RecommendationHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<RecommendationHistoryScreen> {
  int _days = 30;
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final provider = recommendationHistoryProvider(_days, _page);
    return Scaffold(
      appBar: AppBar(title: const Text('Action history')),
      body: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
              ButtonSegment(value: 180, label: Text('180 days')),
            ],
            selected: {_days},
            onSelectionChanged: (value) => setState(() {
              _days = value.single;
              _page = 0;
            }),
          ),
          Expanded(
            child: AccountAsyncView<List<DatedRecommendation>>(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              builder: (context, items) => ListView.builder(
                padding: const EdgeInsets.all(Insets.lg),
                itemCount: items.length + 1,
                itemBuilder: (context, index) => index == items.length
                    ? _paging(items.length)
                    : _entry(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(DatedRecommendation item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.day),
          RecommendationEntry(
            recommendation: item.recommendation,
            showSignal: true,
          ),
          Text(switch (item.recommendation.adopted) {
            true => 'Adopted',
            false => 'Dismissed',
            null => 'Not decided',
          }),
          AccountAsyncView<AccountApi>(
            value: ref.watch(accountApiProvider),
            onRetry: () => ref.invalidate(accountApiProvider),
            builder: (context, api) => Wrap(
              key: ObjectKey(api),
              spacing: Insets.sm,
              children: [
                for (final action in ['adopt', 'dismiss'])
                  ServerActionButton(
                    label: action == 'adopt' ? 'Adopt' : 'Dismiss',
                    action: () => setRecommendationAdoption(
                      api,
                      item.recommendation.id!,
                      action,
                    ),
                    onSaved: () {
                      ref.invalidate(recommendationHistoryProvider);
                      ref.invalidate(todaySnapshotProvider);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _paging(int count) => Column(
    children: [
      if (count == 0) const Text('No actions in this part of your history.'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
            child: const Text('Previous'),
          ),
          Text('Page ${_page + 1}'),
          TextButton(
            onPressed: count == 100 ? () => setState(() => _page++) : null,
            child: const Text('Next'),
          ),
        ],
      ),
    ],
  );
}
