import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/states/current_account_value.dart';

void main() {
  test(
    'reload and failed replacement cannot render previous account data',
    () async {
      var owner = 0;
      Future<String> next = Future.value('private owner A data');
      final account = Provider<int>((ref) => owner);
      final response = FutureProvider<String>((ref) {
        ref.watch(account);
        return next;
      });
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);
      container.listen(response, (_, _) {});
      await container.read(response.future);
      final pending = Completer<String>();
      next = pending.future;
      owner = 1;
      container.invalidate(account);
      await container.pump();
      final loading = container.read(response);
      expect(loading.value, 'private owner A data');
      expect(currentAccountValue(loading).value, isNull);
      final failure = expectLater(
        container.read(response.future),
        throwsException,
      );
      pending.completeError(Exception('offline'));
      await failure;
      expect(currentAccountValue(container.read(response)).value, isNull);
      final retry = Completer<String>();
      next = retry.future;
      container.invalidate(response);
      await container.pump();
      expect(currentAccountValue(container.read(response)).value, isNull);
      retry.complete('owner B data');
      await container.read(response.future);
    },
  );

  test('manual refresh keeps the same account data while waiting', () async {
    Future<String> next = Future.value('current owner data');
    final response = FutureProvider<String>((ref) => next);
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    container.listen(response, (_, _) {});
    await container.read(response.future);
    final pending = Completer<String>();
    next = pending.future;
    container.invalidate(response);
    await container.pump();
    expect(
      currentAccountValue(container.read(response)).value,
      'current owner data',
    );
    pending.complete('updated');
    await container.read(response.future);
  });
}
