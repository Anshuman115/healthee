/// Connect your strap — `H.screens.pairing`, with the real flow under it.
///
/// ```js
/// H.screens.pairing = () => `${H.header('A quiet connection.','Connect your strap',true)}
///   <div class="device-visual">${H.icon('strap')}</div>
///   <h2 class="center">Your health starts here.</h2>
///   <p class="small center section">…</p>
///   <div class="card section"><div class="timeline">
///     <div class="timeline-item"><span class="node active">1</span>…Find your strap…</div>
///     <div class="timeline-item"><span class="node">2</span>…Connect securely…</div>
///     <div class="timeline-item"><span class="node">3</span>…Bring your data together…</div>
///   </div></div>
///   ${H.button('Find my strap','scan','full section','strap')}
///   <p class="form-note center">This button demonstrates pairing…</p>`;
/// ```
///
/// ## The prototype's one screen is our five steps, and the timeline is the seam
///
/// `H.screens.pairing` is a single introduction with one button, because a
/// design preview has nothing to pair. The real flow is a sealed
/// [PairingStep] union — sign in, choose, confirm, paired, or the manual
/// fallback — and it cannot be collapsed into one button without deleting it.
///
/// So the prototype's opening is kept **as the screen's head** and the step's
/// own form is drawn under it. The timeline is not decoration: its `active`
/// node tracks the real step, so the three numbered stages describe where the
/// owner actually is rather than illustrating a journey beside one.
///
/// The mapping is the prototype's own wording against this flow:
///
/// ```text
///   1  Find your strap             ZeppSignInStep · ManualEntryStep · ChooseDeviceStep
///   2  Connect securely            ConfirmStrapStep
///   3  Bring your data together    PairedStep
/// ```
///
/// The `switch` on [PairingStep] is exhaustive because the union is sealed, so
/// a step added later without a widget is a compile error rather than a blank
/// screen — the same guarantee `Reading<T>` gives the honesty states.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
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
import 'package:healthee/shared/v02/emblems.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// Pair a strap, or review the pairing already held.
class PairingScreen extends ConsumerWidget {
  /// [onDone] is what "Done" does — the route back into the app.
  const PairingScreen({this.onDone, super.key});

  /// The prototype's own h1.
  static const String title = 'A quiet connection.';

  /// Its eyebrow.
  static const String eyebrow = 'Connect your strap';

  /// The centred headline under the device figure.
  static const String headline = 'Your health starts here.';

  /// And the sentence under that.
  static const String opening =
      'Keep your Helio Strap nearby. Once paired, its readings become part of '
      'one connected picture.';

  /// Called when the owner leaves a completed pairing. Null in tests.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        const DeviceVisual(),
        Center(
          child: Text(
            headline,
            textAlign: TextAlign.center,
            style: FormType.heading2.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: SectionGap.height),
        const SmallProse(opening, centred: true),
        const SectionGap(),
        AsyncView<({PairedStrap? strap, bool zeppRemembered})>(
          value: ref.watch(pairingSummaryProvider),
          onRetry: () => ref.invalidate(pairingSummaryProvider),
          loadingLabel: 'Checking what is already paired',
          errorMessage: "Couldn't read this phone's keystore",
          builder: (context, summary) =>
              _PairingBody(summary: summary, onDone: onDone),
        ),
      ],
    );
  }
}

/// Where the owner is, drawn as the prototype's three-step timeline.
///
/// Public so a test can assert the node the flow lit rather than the words
/// beside it.
List<TimelineStep> pairingTimeline(PairingStep step) {
  final stage = switch (step) {
    ZeppSignInStep() || ManualEntryStep() || ChooseDeviceStep() => 0,
    ConfirmStrapStep() => 1,
    PairedStep() => 2,
  };
  const List<(String, String)> stages = <(String, String)>[
    (
      'Find your strap',
      'Its key is on your Zepp account, or you can type it in.',
    ),
    (
      'Connect securely',
      'Confirm the strap on the air before anything is stored.',
    ),
    (
      'Bring your data together',
      'The first collection may take a little longer.',
    ),
  ];
  return <TimelineStep>[
    for (var i = 0; i < stages.length; i++)
      TimelineStep(
        title: stages[i].$1,
        body: stages[i].$2,
        active: i == stage,
      ),
  ];
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
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlainCard(child: HTimeline(pairingTimeline(state.step))),
        const SectionGap(),
        _StepBody(state: state, controller: controller, onDone: onDone),
        if (state.failure case final failure?) ...<Widget>[
          const SectionGap(),
          PairingFailureCard(
            failure: failure,
            onRetry: () => _retry(state, controller),
          ),
        ],
        if (state.isBusy) ...<Widget>[
          const SectionGap(),
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
