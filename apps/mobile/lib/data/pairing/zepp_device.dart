/// One device bound to a Zepp account, parsed from the device-list payload.
///
/// ## Three fields are verified; the name is not
///
/// `macAddress`, `activeStatus` and `additionalInfo.auth_key` are the fields the
/// proven reference (`huami_token/models.py`) reads, against a real account.
/// Those are the ones this app depends on, and a payload missing them is a
/// [ZeppApiChanged] rather than a device with blanks in it.
///
/// A **display name** is not among them. The reference never reads one, and this
/// work package was built without access to a real Zepp account to capture one
/// from — so [ZeppDevice.label] tries two plausible keys and, when neither is
/// there, falls back to the MAC and says so via [hasVendorName]. The picker
/// renders that fallback as the MAC plus "Zepp did not name this one", which is
/// true, rather than printing "Amazfit Helio Strap" at a device we cannot
/// actually identify. Guessing a label is the small version of the thing this
/// product exists not to do.
library;

import 'dart:convert';

import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:meta/meta.dart';

/// A strap (or watch) the Zepp account knows about.
@immutable
class ZeppDevice {
  /// Builds a device row. Prefer [ZeppDevice.fromJson].
  const ZeppDevice({
    required this.strap,
    required this.isActive,
    required this.vendorName,
  });

  /// Parses one `items[]` entry.
  ///
  /// Returns null when the entry cannot yield a usable pairing — a missing MAC,
  /// a missing key, or either one malformed. Null rather than throwing, because
  /// one unusable row among several must not cost the owner the devices that
  /// *are* usable; the caller reports "none of the N devices carried a key" only
  /// when every row comes back null.
  static ZeppDevice? fromJson(Map<String, Object?> item) {
    final mac = item['macAddress'];
    if (mac is! String || mac.isEmpty) {
      return null;
    }

    final info = _additionalInfo(item['additionalInfo']);
    final key = info['auth_key'];
    if (key is! String || key.isEmpty) {
      return null;
    }

    final PairedStrap strap;
    try {
      strap = PairedStrap.parse(mac: mac, authKey: key);
    } on Exception {
      // A row whose key is not 16 bytes is not this strap's key. Dropping it is
      // the honest read; storing it would fail later inside the handshake.
      return null;
    }

    final name = _firstString([info['deviceName'], item['deviceType']]);
    return ZeppDevice(
      strap: strap,
      isActive: _isTruthy(item['activeStatus']),
      vendorName: name,
    );
  }

  /// The MAC and auth key, already validated.
  final PairedStrap strap;

  /// Zepp's own "this is the device currently in use" flag.
  final bool isActive;

  /// The name Zepp gave it, when it gave one. Null is the common case.
  final String? vendorName;

  /// Whether [label] is a real name rather than the MAC standing in for one.
  bool get hasVendorName => vendorName != null;

  /// What to show in the picker.
  String get label => vendorName ?? strap.mac;

  /// `additionalInfo` arrives as a JSON *string* in the reference. Accept a map
  /// too: both are honest parses of the same field, and pinning only one shape
  /// would turn a harmless server-side change into a pairing outage.
  static Map<String, Object?> _additionalInfo(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    }
    return const {};
  }

  static String? _firstString(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static bool _isTruthy(Object? value) => switch (value) {
    final bool flag => flag,
    final int number => number != 0,
    final String text => text == '1' || text.toLowerCase() == 'true',
    _ => false,
  };

  /// Names the device and says nothing about its key. See [PairedStrap.toString].
  @override
  String toString() => 'ZeppDevice(${strap.mac}, active: $isActive)';
}
