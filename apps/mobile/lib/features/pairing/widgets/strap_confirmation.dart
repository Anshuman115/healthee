/// "Is it actually here?" — the step between holding credentials and pairing.
///
/// A scan is evidence, not decoration. Credentials from an account say a strap
/// *exists*; an advertisement says *this* strap is on this owner's wrist, in
/// this room, right now. The two are different claims and the second is the one
/// the next work package depends on.
///
/// Confirming is not compulsory. A scan cannot run on a platform that hides MAC
/// addresses (iOS), and it will fail honestly for someone pairing a strap that
/// is charging in another room. Both are stated, and pairing stays available —
/// refusing to save a correct pairing because we could not hear it would be
/// certainty we do not have.
library;

import 'package:flutter/material.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Shows the chosen strap, the scan result, and the pair button.
class StrapConfirmation extends StatelessWidget {
  /// [outcome] is null until a scan has run.
  const StrapConfirmation({
    required this.strap,
    required this.outcome,
    required this.onScan,
    required this.onPair,
    required this.enabled,
    super.key,
  });

  /// The strap about to be paired.
  final PairedStrap strap;

  /// What the last scan found, if one has finished.
  final ScanOutcome? outcome;

  /// Runs (or re-runs) the scan.
  final VoidCallback onScan;

  /// Writes the pairing to the keystore.
  final VoidCallback onPair;

  /// False while work is in flight.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm this strap', style: text.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(strap.mac, style: text.titleSmall),
          const SizedBox(height: Insets.xs),
          // The key is never rendered, in full or in part. It is a device secret
          // and a screenshot is a wire.
          Text(
            'Pairing key read and held — not shown, and never sent anywhere.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Insets.lg),
          _ScanReport(outcome: outcome),
          const SizedBox(height: Insets.lg),
          Text(
            PairingDisclosure.whatIsAlwaysStored,
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: enabled ? onScan : null,
                child: Text(outcome == null ? 'Scan for it' : 'Scan again'),
              ),
              const SizedBox(width: Insets.md),
              FilledButton(
                onPressed: enabled ? onPair : null,
                child: const Text('Pair'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanReport extends StatelessWidget {
  const _ScanReport({required this.outcome});

  final ScanOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final (String headline, String detail) = switch (outcome) {
      null => (
        'Not confirmed yet',
        'A scan takes about ${kScanWindow.inSeconds} seconds and only listens — '
            'it does not connect to the strap.',
      ),
      // `fav` is the one place colour is earned here: the strap answering is a
      // favourable fact, and the ladder's own token is what says so elsewhere.
      final StrapSighted sighted => (
        'Heard it — ${sighted.rssi} dBm',
        sighted.advertisedName.isEmpty
            ? 'It is advertising nearby. That is as much as a scan can prove; the '
                  'first sync proves the key.'
            : 'Advertising as "${sighted.advertisedName}". The first sync proves '
                  'the key.',
      ),
      final ScanNotPossibleHere blocked => ('Cannot check here', blocked.reason),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: text.titleSmall?.copyWith(
            color: outcome is StrapSighted ? colors.fav : colors.ink,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(detail, style: text.bodySmall?.copyWith(color: colors.ink2)),
      ],
    );
  }
}
