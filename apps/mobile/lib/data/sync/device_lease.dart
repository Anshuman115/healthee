import 'dart:async';

import 'package:drift/drift.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:uuid/uuid.dart';

/// SQLite arbitration across UI/background isolates. Killed owners expire.
class DeviceLease {
  DeviceLease(
    this.store, {
    this.resource = 'strap_lease',
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final LocalStore store;
  final String resource;
  final DateTime Function() now;
  final String _owner = const Uuid().v4();
  Timer? _renewal;
  static const expiry = Duration(minutes: 30);
  static const heartbeat = Duration(minutes: 1);
  bool _held = false;
  bool _closed = false;

  Future<bool> acquire() async {
    if (_closed) return false;
    if (_held) return true;
    final until = now().add(expiry).millisecondsSinceEpoch;
    final updated = await store.customUpdate(
      'INSERT INTO sync_meta(name, value) VALUES (?, ?) '
      'ON CONFLICT(name) DO UPDATE SET value = excluded.value '
      'WHERE CAST(substr(sync_meta.value, 38) AS INTEGER) < ?',
      variables: [
        Variable(resource),
        Variable('$_owner:$until'),
        Variable(now().millisecondsSinceEpoch),
      ],
      updates: {store.syncMeta},
    );
    _held = updated == 1;
    if (_closed) {
      await release();
      return false;
    }
    if (_held) _renewal = Timer.periodic(heartbeat, (_) => unawaited(_renew()));
    return _held;
  }

  /// Stop timers synchronously during teardown, including an in-flight acquire.
  /// The connection owner still releases the row after closing its session.
  void stopRenewing() {
    _closed = true;
    _renewal?.cancel();
    _renewal = null;
  }

  Future<void> _renew() async {
    try {
      await store.customUpdate(
        'UPDATE sync_meta SET value = ? WHERE name = ? AND substr(value, 1, 36) = ?',
        variables: [
          Variable('$_owner:${now().add(expiry).millisecondsSinceEpoch}'),
          Variable(resource),
          Variable(_owner),
        ],
      );
    } on Exception catch (error, stack) {
      AppLog.failure(
        'sync',
        'renewing device connection ownership',
        error,
        stack,
      );
    }
  }

  Future<void> release() async {
    _renewal?.cancel();
    _renewal = null;
    if (!_held) return;
    await store.customUpdate(
      'DELETE FROM sync_meta WHERE name = ? AND substr(value, 1, 36) = ?',
      variables: [Variable(resource), Variable(_owner)],
      updates: {store.syncMeta},
    );
    _held = false;
  }
}
