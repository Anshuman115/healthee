/// The sign-in form borrows the Zepp EMAIL, and never the Zepp password.
///
/// ## Why this is a test and not a comment
///
/// The convenience is real: the owner typed that address on this phone when
/// they paired the strap, and it is almost always the one they want here. The
/// temptation next door is to take the password too — the app has it in the
/// keystore, and it would make signing in a single tap.
///
/// **It must not.** That password belongs to Amazfit. Making it the key to the
/// health record as well means one breach opens both, which is the amplification
/// that makes credential stuffing work at all. Two services, two passwords, and
/// the owner chooses this one.
///
/// So the assertions are a pair: the email IS prefilled, and the password is
/// nowhere in the widget tree — not in a field, not in a semantics label, not in
/// a hint. A test that only checked the first would pass just as happily against
/// a form that filled in both.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/auth/identity_providers.dart';
import 'package:healthee/features/signin/server_signin_screen.dart';

import '../pairing/_pairing_fakes.dart';
import '_signin_fakes.dart';

const String _email = 'owner@zepp.example';
const String _password = 'the-zepp-password-never-reused';

Widget _host(FakeSecretStore store, ScriptedServer server) {
  return ProviderScope(
    overrides: [
      credentialsProvider.overrideWithValue(Credentials(store)),
      // A build that CAN sign in, so the email/password form is the one drawn.
      identityAvailableProvider.overrideWithValue(true),
      serverSessionRepositoryProvider.overrideWithValue(
        repositoryWith(store, server),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const ServerSignInScreen(),
    ),
  );
}

/// Every string the screen laid out, including hints and semantics labels.
List<String> _everythingOnScreen(WidgetTester tester) => <String>[
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final String said) said,
  for (final field in tester.widgetList<TextField>(find.byType(TextField)))
    ...<String>[
      field.controller?.text ?? '',
      field.decoration?.hintText ?? '',
      field.decoration?.labelText ?? '',
    ],
  for (final semantics in tester.widgetList<Semantics>(find.byType(Semantics)))
    semantics.properties.label ?? '',
];

void main() {
  testWidgets('THE EMAIL IS BORROWED AND THE PASSWORD IS NOT', (tester) async {
    tester.view
      ..physicalSize = const Size(420, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = FakeSecretStore();
    await Credentials(store).setZeppAccount(
      email: _email,
      password: _password,
    );

    await tester.pumpWidget(_host(store, ScriptedServer()));
    await tester.pumpAndSettle();

    final said = _everythingOnScreen(tester);
    expect(
      said,
      contains(_email),
      reason: 'the address the owner already typed on this phone',
    );
    expect(
      said.join('\n'),
      isNot(contains(_password)),
      reason: 'the Zepp password belongs to Amazfit and stays there',
    );
  });

  testWidgets('with no paired strap the email is simply empty', (tester) async {
    tester.view
      ..physicalSize = const Size(420, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(FakeSecretStore(), ScriptedServer()));
    await tester.pumpAndSettle();

    // Nothing invented: a blank field is the honest state when this phone has
    // never been told an address.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.where((field) => (field.controller?.text ?? '').contains('@')),
      isEmpty,
    );
  });
}
