import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/data/journal/journal_feed.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/features/journal/journal_screen.dart';

void main() {
  late Dio dio;
  late JournalRepository repository;
  final writes = <RequestOptions>[];
  var reject = false;
  setUp(() async {
    writes.clear();
    reject = false;
    dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
    repository = JournalRepository(dio, await CacheSession.capture(null));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          writes.add(request);
          if (reject) {
            handler.reject(
              DioException.connectionError(
                requestOptions: request,
                reason: 'offline',
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                data: <String, Object?>{'ok': true},
              ),
            );
          }
        },
      ),
    );
  });
  tearDown(() => dio.close());

  Widget host({bool signedIn = true}) => ProviderScope(
    overrides: [
      serverSessionProvider.overrideWith(
        (ref) async => signedIn
            ? const ServerSessionStatus(
                signedIn: true,
                baseUrl: 'https://test.example',
              )
            : const ServerSessionStatus.signedOut(),
      ),
      journalRepositoryProvider.overrideWith((ref) async => repository),
      journalFeedProvider.overrideWith(
        (ref) => Stream.value(
          ServerSnapshot(
            const JournalFeed(entries: [], fastOpen: false),
            fetchedAt: DateTime.utc(2026, 9, 6),
          ),
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const JournalScreen()),
  );

  testWidgets('signed out owner gets a sign-in action, no editable journal', (
    tester,
  ) async {
    await tester.pumpWidget(host(signedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to save your journal'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('invalid input remains editable and is not sent', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '-20');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
  });

  testWidgets('successful save clears form only after acknowledgement', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '80');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(writes.single.data, containsPair('amount', 80.0));
    expect(find.text('Saved.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('failed save retains draft and reports unconfirmed outcome', (
    tester,
  ) async {
    reject = true;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '80');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save could not be confirmed'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '80',
    );
  });
}
