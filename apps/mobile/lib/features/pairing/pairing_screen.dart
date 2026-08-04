/// The pairing screen: composition only.
///
/// Standards §3 — "a screen file lays out modules; each module widget lives in
/// its own file". The switch below picks a module per step and the modules do
/// the drawing; the logic is all in `pairing_controller.dart`.
///
/// The `switch` on [PairingStep] is exhaustive because the union is sealed, so a
/// step added later without a widget is a compile error rather than a blank
/// screen — the same guarantee `Reading<T>` gives the honesty states, applied to
/// the flow.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/pairing/pairing_controller.dart';
import 'package:healthee/features/pairing/pairing_state.dart';
import 'package:healthee/features/pairing/widgets/device_picker.dart';
import 'package:healthee/features/pairing/widgets/manual_entry_form.dart';
import 'package:healthee/features/pairing/widgets/paired_summary.dart';
import 'package:healthee/features/pairing/widgets/pairing_failure_card.dart';
import 'package:healthee/features/pairing/widgets/strap_confirmation.dart';
import 'package:healthee/features/pairing/widgets/zepp_sign_in_form.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Pair a strap, or review the pairing already held.
class PairingScreen extends ConsumerWidget {
  /// [onDone] is what "Done" does — the route back into the app.
  const PairingScreen({this.onDone, super.key});

  /// Called when the owner leaves a completed pairing. Null in tests.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your strap')),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          AsyncView<({PairedStrap? strap, bool zeppRemembered})>(
            value: ref.watch(pairingSummaryProvider),
            onRetry: () => ref.invalidate(pairingSummaryProvider),
            loadingLabel: 'Checking what is already paired',
            errorMessage: "Couldn't read this phone's keystore",
            builder: (context, summary) => _PairingBody(summary: summary, onDone: onDone),
          ),
          const SizedBox(height: Insets.xl),
          const _ServerRow(),
        ],
      ),
    );
  }
}

/// The way to the server session, from the surface that already answers "what
/// does this phone hold".
///
/// It belongs here rather than on a new screen: the Today header's avatar is
/// labelled "Your strap and pairing" and comes here because this is, in that
/// widget's own words, "the only identity surface that exists". The server
/// session is the second thing this phone keeps about the owner's setup, and
/// **it is the only way to reach sign-out** — the Today data-health strip
/// speaks up when there is no session and is deliberately silent when there is.
///
/// It reaches the sign-in feature by ROUTE, not by import. Standards §3:
/// "nothing reaches into another feature".
class _ServerRow extends ConsumerWidget {
  const _ServerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final session = ref.watch(serverSessionProvider).value;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your server', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text(
            session == null
                ? 'Checking…'
                : session.signedIn
                ? 'Signed in to ${session.host}'
                : 'Not signed in. Your strap still syncs to this phone.',
            style: text.titleSmall,
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => context.go(Routes.serverSignIn),
              child: Text(
                session?.signedIn ?? false ? 'Manage' : 'Sign in to your server',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingBody extends ConsumerWidget {
  const _PairingBody({required this.summary, required this.onDone});

  final ({PairedStrap? strap, bool zeppRemembered}) summary;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pairingControllerProvider);
    final controller = ref.read(pairingControllerProvider.notifier);
    final existing = summary.strap;

    // A strap is already paired and the owner has not started a new flow: show
    // what is held rather than a form that would silently overwrite it.
    if (state.step is ZeppSignInStep && existing != null) {
      return PairedSummary(
        strap: existing,
        zeppRemembered: summary.zeppRemembered,
        onUnpair: () => unawaited(controller.unpair()),
        onDone: onDone ?? () {},
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepBody(state: state, controller: controller, onDone: onDone),
        if (state.failure case final failure?) ...[
          const SizedBox(height: Insets.lg),
          PairingFailureCard(
            failure: failure,
            onRetry: () => _retry(state, controller),
          ),
        ],
        if (state.isBusy) ...[
          const SizedBox(height: Insets.lg),
          LoadingState(label: state.busyLabel),
        ],
      ],
    );
  }

  /// What "Try again" means depends on the step it is offered on. Retrying a
  /// scan re-scans; retrying anything else returns to the form that produced it,
  /// because the input is what has to change.
  void _retry(PairingState state, PairingController controller) {
    switch (state.step) {
      case ConfirmStrapStep():
        unawaited(controller.scan());
      case ZeppSignInStep():
      case ManualEntryStep():
      case ChooseDeviceStep():
      case PairedStep():
        controller.restart();
    }
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.state,
    required this.controller,
    required this.onDone,
  });

  final PairingState state;
  final PairingController controller;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final enabled = !state.isBusy;
    return switch (state.step) {
      ZeppSignInStep() => ZeppSignInForm(
        enabled: enabled,
        rememberZepp: state.rememberZepp,
        onRememberChanged: (value) => controller.setRememberZepp(value: value),
        onUseManualEntry: controller.useManualEntry,
        onSubmit: (email, password) =>
            unawaited(controller.signIn(email: email, password: password)),
      ),
      ManualEntryStep() => ManualEntryForm(
        enabled: enabled,
        onUseAccount: controller.useAccountEntry,
        onSubmit: (mac, authKey) =>
            controller.enterManually(mac: mac, authKey: authKey),
      ),
      final ChooseDeviceStep step => DevicePicker(
        devices: step.devices,
        onSelected: controller.chooseDevice,
      ),
      final ConfirmStrapStep step => StrapConfirmation(
        strap: step.strap,
        outcome: step.outcome,
        enabled: enabled,
        onScan: () => unawaited(controller.scan()),
        onPair: () => unawaited(controller.pair()),
      ),
      final PairedStep step => PairedSummary(
        strap: step.strap,
        zeppRemembered: state.rememberZepp,
        onUnpair: () => unawaited(controller.unpair()),
        onDone: onDone ?? () {},
      ),
    };
  }
}
