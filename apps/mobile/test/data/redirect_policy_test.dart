/// **No dio in this app follows a redirect.** This reads `lib/` and proves it.
///
/// `AUTH_AUDIT.md` A1 — the only path in the whole audit by which a credential
/// reaches a party not already entitled to it.
///
/// Dio defaults to `followRedirects: true` with `maxRedirects: 5`, and the IO
/// adapter passes both straight to `dart:io`'s `HttpClientRequest`, which
/// replays the request headers — `Authorization` included — at whatever host
/// the `Location` names. `ServerSessionInterceptor` attaches that header before
/// the redirect happens, so a 3xx from a misconfigured proxy (or from a host an
/// owner was talked into signing into) sends the token onward.
///
/// ## Why a source scan and not only a behavioural test
///
/// The rule was ALREADY known and ALREADY applied: `server_probe.dart` sets
/// `followRedirects: false` and its library docstring names this exact leak in
/// its own words. `zepp_client.dart` sets it too. The client that carries the
/// token for the rest of the app's life did not. **One client remembering is
/// what produced the defect**, so the guarantee cannot be one more thing to
/// remember — a fourth dio added next year has to fail this test on the day it
/// is written.
///
/// A behavioural test cannot give that: following a redirect is the HTTP
/// ADAPTER's job, so a fake adapter (which is how every other network test here
/// works) never redirects at all and would pass against a client that would
/// leak in production. What can be asserted behaviourally is the constructed
/// options of the real provider, and that is asserted too, below — the two
/// together are "this instance is right" plus "every instance must be".
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_probe.dart';
import 'package:healthee/data/pairing/zepp_client.dart';

import '../pairing/_pairing_fakes.dart';

/// A `Dio(` construction, and the `BaseOptions(...)` that follows it.
///
/// Deliberately crude and deliberately greedy: it takes everything up to the
/// first `);` at the start of a line, which spans the whole multi-line
/// `BaseOptions` block in every construction in `lib/`. A parser would be more
/// precise and would also be a second thing that can be wrong.
final RegExp _dioConstruction = RegExp(
  r'Dio\((?:.|\n)*?\n\s*\);',
);

/// Every non-generated Dart file under `lib/`.
Iterable<File> _sourceFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.drift.dart')) {
      continue;
    }
    yield entity;
  }
}

void main() {
  test('every dio constructed in lib/ refuses to follow redirects', () {
    final offenders = <String>[];
    var found = 0;
    for (final file in _sourceFiles()) {
      final source = file.readAsStringSync();
      for (final match in _dioConstruction.allMatches(source)) {
        found++;
        final construction = match.group(0)!;
        if (!construction.contains('followRedirects: false')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    // The premise of the assertion below. A regex that matched nothing would
    // make "no offenders" trivially true — the vacuous-guard failure this repo
    // has recorded more than once.
    expect(
      found,
      greaterThanOrEqualTo(3),
      reason: 'the scan found only $found dio constructions in lib/',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'these dio instances follow redirects, which replays the Authorization '
          'header at whatever host a 3xx names: $offenders',
    );
  });

  test('the scan would catch a dio that omitted the setting', () {
    // The planted violation. Without this the test above proves only that the
    // regex found three matches, not that it can tell a good one from a bad one.
    const planted = '''
Dio(
  BaseOptions(
    baseUrl: 'https://example.com',
  ),
);
''';
    final match = _dioConstruction.firstMatch(planted);
    expect(match, isNotNull, reason: 'the scanner failed to see a plain Dio(...)');
    expect(match!.group(0)!.contains('followRedirects: false'), isFalse);
  });

  test('the app client itself is built with redirects off', () {
    // The real provider, built the way the app builds it — so this fails if the
    // options move somewhere the source scan cannot see, such as an interceptor
    // or a per-request `Options`.
    final container = ProviderContainer(
      overrides: [
        credentialsProvider.overrideWithValue(Credentials(FakeSecretStore())),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(apiClientProvider);
    expect(dio.options.followRedirects, isFalse);
    expect(dio.options.maxRedirects, 0);
  });

  test('the two clients that already had the rule still have it', () {
    // Not redundant with the scan: these two are where the rule was WRITTEN
    // DOWN, and a future refactor that moved their options out of the literal
    // would slip past a source scan while still being correct here.
    expect(ServerProbe.dioFor().options.followRedirects, isFalse);
    expect(ZeppClient.dioFor().options.followRedirects, isFalse);
  });
}
