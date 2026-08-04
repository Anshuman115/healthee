/// The account's straps. Tap one.
///
/// One outer card with hairline-divided rows, never a card per device — brief §2
/// bans a card inside a card, and a list of two devices rendered as two cards is
/// exactly that shape.
///
/// ## A row that has no name says so
///
/// The Zepp payload is not guaranteed to carry a display name, and this work
/// package had no real account to capture one from (`zepp_device.dart`). A row
/// without one shows the MAC as its title and "Zepp did not name this one"
/// underneath. That is worse-looking than printing "Amazfit Helio Strap" at
/// every row, and it is the only honest option: a label is a claim about which
/// device this is, and the wrong one gets the wrong strap paired.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/pairing/zepp_device.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Renders the device list from a Zepp account.
class DevicePicker extends StatelessWidget {
  /// [devices] is never empty — an empty account is a named failure instead.
  const DevicePicker({required this.devices, required this.onSelected, super.key});

  /// The straps to choose from.
  final List<ZeppDevice> devices;

  /// Called with the tapped device.
  final ValueChanged<ZeppDevice> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Zepp devices', style: text.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(
            'Tap the strap you wear. Nothing is stored until you confirm it on '
            'the next screen.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.md),
          for (final device in devices)
            _DeviceRow(
              device: device,
              onTap: () => onSelected(device),
              isFirst: device == devices.first,
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.onTap,
    required this.isFirst,
  });

  final ZeppDevice device;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(top: BorderSide(color: colors.line2, width: hairline)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.label, style: text.titleSmall),
                    const SizedBox(height: Insets.xs),
                    Text(
                      device.hasVendorName
                          ? device.strap.mac
                          : 'Zepp did not name this one',
                      style: text.bodySmall?.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              if (device.isActive)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Text(
                    'IN USE',
                    style: text.labelSmall?.copyWith(color: colors.accent),
                  ),
                ),
              Icon(Icons.chevron_right, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
