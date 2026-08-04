/// [StrapLink] over `flutter_blue_plus` — the real radio.
///
/// The connect sequence is the legacy one, in the legacy order: connect,
/// request MTU 247, discover services, find the four protocol characteristics
/// plus the standard battery one, subscribe to `0x0017`. The order matters —
/// the chunked encoder sizes its chunks from the MTU, so requesting it after
/// the first write would silently fragment differently.
///
/// This file is the only one in `ble/` that imports `flutter_blue_plus`, and it
/// holds no protocol logic at all. That is the point of the seam: everything
/// worth testing sits on the other side of it.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/core/logging.dart';

/// The MTU the strap grants, and the one the chunked encoder assumes.
const int kStrapMtu = 247;

/// How long to wait for the connection itself.
const Duration kConnectTimeout = Duration(seconds: 20);

/// A real BLE connection to one strap.
class BluetoothStrapLink implements StrapLink {
  /// Talks to the strap at [mac].
  BluetoothStrapLink(this.mac);

  /// The strap's Bluetooth address.
  final String mac;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  BluetoothCharacteristic? _notify;
  BluetoothCharacteristic? _control;
  BluetoothCharacteristic? _data;
  BluetoothCharacteristic? _battery;
  StreamSubscription<BluetoothConnectionState>? _connectionLog;

  @override
  bool get hasActivityChannel => _control != null && _data != null;

  @override
  Future<void> open() async {
    final device = BluetoothDevice.fromId(mac);
    _device = device;
    _connectionLog = device.connectionState.listen((state) {
      AppLog.info('ble', 'connection: ${state.name}');
    });

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: kConnectTimeout,
        autoConnect: false,
      );
    } on FlutterBluePlusException catch (error, stackTrace) {
      AppLog.failure('ble', 'connecting to the paired strap', error, stackTrace);
      throw StrapException(StrapUnreachable(error.function));
    } on TimeoutException catch (error, stackTrace) {
      AppLog.failure('ble', 'connecting to the paired strap', error, stackTrace);
      throw const StrapException(
        StrapUnreachable('it did not answer within 20 seconds'),
      );
    }

    // Best-effort: a strap that refuses the larger MTU still works, it just
    // fragments more. Not a failure, so it is logged and stepped over.
    try {
      final mtu = await device.requestMtu(kStrapMtu);
      AppLog.info('ble', 'MTU = $mtu');
    } on FlutterBluePlusException catch (error, stackTrace) {
      AppLog.failure('ble', 'requesting MTU $kStrapMtu', error, stackTrace);
    }

    await _discover(device);
    await _notify!.setNotifyValue(true);
  }

  Future<void> _discover(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final uuid = characteristic.uuid.str.toLowerCase();
        if (uuid == StrapLink.writeUuid) _write = characteristic;
        if (uuid == StrapLink.notifyUuid) _notify = characteristic;
        if (uuid == StrapLink.controlUuid) _control = characteristic;
        if (uuid == StrapLink.dataUuid) _data = characteristic;
        if (uuid.contains('2a19')) _battery = characteristic;
      }
    }
    if (_write == null || _notify == null) {
      AppLog.warning(
        'ble',
        'chunked chars not found (write=${_write != null}, '
            'notify=${_notify != null}) across ${services.length} services',
      );
      throw const StrapException(
        StrapChannelsMissing('chunked transport (0x0016 / 0x0017)'),
      );
    }
  }

  @override
  Future<void> openActivityChannel() async {
    final control = _control;
    final data = _data;
    if (control == null || data == null) {
      throw const StrapException(
        StrapChannelsMissing('activity fetch (0x0004 / 0x0005)'),
      );
    }
    await control.setNotifyValue(true);
    await data.setNotifyValue(true);
  }

  @override
  Future<int?> readBatteryPercent() async {
    final battery = _battery;
    if (battery == null) return null;
    try {
      final value = await battery.read();
      if (value.isEmpty) return null;
      final percent = value.first;
      return (percent >= 0 && percent <= 100) ? percent : null;
    } on FlutterBluePlusException catch (error, stackTrace) {
      // Not fatal: the battery pill is a nicety and the sync is not.
      AppLog.failure('ble', 'reading the strap battery level', error, stackTrace);
      return null;
    }
  }

  @override
  Stream<Uint8List> get chunkedNotifications => _bytes(_notify);

  @override
  Stream<Uint8List> get activityControl => _bytes(_control);

  @override
  Stream<Uint8List> get activityData => _bytes(_data);

  static Stream<Uint8List> _bytes(BluetoothCharacteristic? characteristic) {
    if (characteristic == null) return const Stream<Uint8List>.empty();
    return characteristic.onValueReceived.map(Uint8List.fromList);
  }

  @override
  Future<void> writeChunk(Uint8List chunk) =>
      _write!.write(chunk, withoutResponse: true);

  @override
  Future<void> writeChunkedAck(Uint8List ack) =>
      _notify!.write(ack, withoutResponse: true);

  @override
  Future<void> writeActivityControl(List<int> command) =>
      _control!.write(command, withoutResponse: true);

  @override
  Future<void> close() async {
    await _connectionLog?.cancel();
    _connectionLog = null;
    final device = _device;
    if (device == null) return;
    try {
      await device.disconnect();
    } on FlutterBluePlusException catch (error, stackTrace) {
      // Legacy swallowed this one entirely. A disconnect that fails is still
      // worth a line: it is how "the strap is still held by someone" looks.
      AppLog.failure('ble', 'disconnecting from the strap', error, stackTrace);
    }
  }
}
