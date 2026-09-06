import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Account transitions hide old data; denied access is distinct from no data.
class AccountAsyncView<T> extends StatelessWidget {
  const AccountAsyncView({
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => currentAccountValue(value).when(
    data: (data) => builder(context, data),
    loading: () => const LoadingState(),
    error: (error, stack) => ErrorState(
      message: apiProblem(error),
      detail: 'Refresh after resolving the issue.',
      onRetry: onRetry,
    ),
  );
}
