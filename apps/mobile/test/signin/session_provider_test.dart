import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:healthee/features/coach/coach_controller.dart';

import '../pairing/_pairing_fakes.dart';

class PendingCoach implements CoachClient {
  final answer = Completer<CoachAnswer>();

  @override
  Future<CoachAnswer> ask(List<CoachTurn> messages) => answer.future;

  @override
  Future<Entitlement> entitlement() async => Entitlement.fromJson(const {});
}

void main() {
  test(
    'a session switch rebuilds clients and drops old in-flight coach state',
    () async {
      final credentials = Credentials(FakeSecretStore());
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'owner-a',
      );
      final clients = <PendingCoach>[];
      final container = ProviderContainer(
        overrides: [
          credentialsProvider.overrideWithValue(credentials),
          coachClientProvider.overrideWith((ref) {
            ref.watch(apiClientProvider);
            final client = PendingCoach();
            clients.add(client);
            return client;
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(serverSessionProvider.future);
      container.listen(coachControllerProvider, (_, _) {});
      await container.pump();
      final originalApi = container.read(apiClientProvider);
      final originalCoach = clients.last;
      final asking = container
          .read(coachControllerProvider.notifier)
          .ask('A private question');
      expect(container.read(coachControllerProvider).isEmpty, isFalse);

      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'owner-b',
      );
      container.invalidate(serverSessionProvider);
      await container.read(serverSessionProvider.future);
      await container.pump();
      expect(
        identical(container.read(apiClientProvider), originalApi),
        isFalse,
      );
      expect(container.read(coachControllerProvider).isEmpty, isTrue);
      originalCoach.answer.complete(
        CoachAnswer.fromJson(const {'reply': 'A private answer'}),
      );
      await asking;
      expect(container.read(coachControllerProvider).isEmpty, isTrue);
    },
  );
}
