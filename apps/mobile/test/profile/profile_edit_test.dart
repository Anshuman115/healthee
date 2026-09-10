import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/profile/health_profile.dart';
import 'package:healthee/data/profile/profile_repository.dart';
import 'package:healthee/features/profile/profile_screen.dart';
import 'package:healthee/shared/v02/buttons.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  late Dio dio;
  late Credentials credentials;
  late ProfileRepository repository;
  final requests = <RequestOptions>[];
  setUp(() async {
    requests.clear();
    credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'owner-a',
      kind: StoredCredentialKind.shared,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              data: <String, Object?>{'ok': true},
            ),
          );
        },
      ),
    );
    repository = ProfileRepository(
      AccountApi(dio, await CacheSession.capture(credentials)),
    );
  });
  tearDown(() => dio.close());

  test(
    'birthday stays an ISO date and a missing weigh-in is omitted',
    () async {
      await repository.save(
        name: 'Owner',
        heightCm: 176,
        sex: 'male',
        dobDate: '1994-07-01',
      );
      expect(requests.single.method, 'PATCH');
      expect(requests.single.data, {
        'name': 'Owner',
        'height_cm': 176.0,
        'sex': 'male',
        'dob_date': '1994-07-01',
      });
    },
  );

  test(
    'account changes reject the old form before sending any write',
    () async {
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'owner-b',
        kind: StoredCredentialKind.shared,
      );
      await expectLater(
        repository.save(name: 'Owner A', heightCm: 176, sex: 'male'),
        throwsA(isA<DioException>()),
      );
      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'stored weight is labelled with its date, never prefilled as today',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWith((ref) async => repository),
            healthProfileProvider.overrideWith(
              (ref) async => const HealthProfile(
                name: 'Owner',
                heightCm: 176,
                sex: 'male',
                dobDate: '1994-07-01',
                weightKg: 72.5,
                weightAsOf: '2026-07-31',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('2026-07-31'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('2026-07-31'), findsOneWidget);
      // v02 keeps the new-weigh-in field behind a button, so it has to be
      // revealed before it can be read. Without this the last `TextField` on
      // the screen is HEIGHT, and the assertion below would be about the wrong
      // control while still reading like it passed.
      final reveal = find.widgetWithText(HButton, 'Log a new weigh-in');
      await tester.ensureVisible(reveal);
      await tester.pumpAndSettle();
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
        reason: 'the stored weight is never prefilled as today’s measurement',
      );
      final save = find.widgetWithText(HButton, 'Save profile');
      // The pump between is load-bearing: `ensureVisible` starts an ANIMATED
      // scroll, so tapping straight after it aims at where the button was.
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(requests.single.data, isNot(contains('measured_weight_kg')));
    },
  );
}
