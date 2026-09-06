/// Activity fetch over the legacy plaintext path — control on char `0x0004`,
/// data on char `0x0005`.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// activity_fetcher.dart`. This is the path proven on the Helio Strap by
/// HelioCore; it is the same protocol Gadgetbridge uses, just not over the
/// ZeppOS chunked transport. The strap reports service `0x004b` as
/// unsupported, which is what makes this the correct path rather than a
/// fallback.
///
/// ## The round protocol (== Gadgetbridge's `AbstractFetchOperation`)
///
/// ```text
///   app  →  0x0004   [0x01, type] ‖ HuamiTime.bytes(since)
///   dev  →  0x0004   [0x10, 0x01, status, expected u32 LE, date …]
///   app  →  0x0004   [0x02]
///   dev  →  0x0005   [counter, payload …]  × n
///   dev  →  0x0004   [0x10, 0x02, status]
///   app  →  0x0004   [0x03, 0x09]          0x09 = KEEP the data on the band
/// ```
///
/// The ack byte is `0x09`, never the destructive one: everything stays on the
/// strap, so any round can be fetched again. That is what makes a re-sync
/// possible after a bad parse, and it is not negotiable.
///
/// ## The 0xFF gap-skip — why the pager does not stall
///
/// Paging normally advances `since` to one minute past the last decoded sample.
/// An all-`0xFF` round decodes to **no samples at all**, so there is nothing to
/// advance past and the pager would re-request the same window forever, never
/// reaching the live data on the far side of the gap. This is not hypothetical:
/// stress stopped writing to the legacy buffer around 2026-06-04 and resumed
/// weeks later, and `project_steps_stuck_pager_stall` exists because of exactly
/// this behaviour on the step stream.
///
/// So for the two per-minute types (`0x01` activity, `0x13` stress) an empty
/// round steps `since` forward by the round's own minute count instead —
/// activity is 8 bytes per minute, stress is 1 — which crosses the gap. Skipping
/// minutes the strap never wrote loses nothing.
///
/// ## Two adaptations
///
///  * The legacy `log` callback is replaced by [AppLog].
///  * Control writes were fire-and-forget. They are now sent through
///    [_writeControl], which logs a failure with context and ends the job with a
///    named failure. Completed rounds survive in `FetchException`; a timeout
///    or a failed write cannot certify an empty-but-successful stream.
///  * Packet-counter gaps discard and retry the round before any parsing.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:healthee/ble/fetch/fetch_exception.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/parsers/activity_parser.dart';
import 'package:healthee/ble/parsers/workout_parser.dart';
import 'package:healthee/ble/transport/huami_time.dart';
import 'package:healthee/core/logging.dart';

/// Drives one fetch type at a time over the control/data characteristic pair.
class ActivityFetcher {
  /// [writeControl] writes to char `0x0004`; feed char `0x0004` notifications
  /// to [onControl] and char `0x0005` notifications to [onData].
  ActivityFetcher(this.writeControl);

  static const int _maxIntegrityRetries = 2;
  static const int _response = 0x10;
  static const int _cmdStartDate = 0x01;
  static const int _cmdFetchData = 0x02;
  static const int _cmdAck = 0x03;
  static const int _ackKeep = 0x09; // keep data on band — never delete

  /// Writes one control command to char `0x0004`.
  final Future<void> Function(List<int>) writeControl;

  _FetchJob? _job;

  /// Packets the device reported for the last type. `-1` = rejected/no reply.
  int lastExpected = 0;

  /// Full raw bytes of the last type, across every round it paged.
  Uint8List lastRaw = Uint8List(0);

  /// Probe a code: send the start command, read the metadata reply, then
  /// ack-abort WITHOUT downloading data. Returns the reported packet count
  /// (0 = supported but empty, -1 = rejected/no reply). Fast scan.
  Future<int> probe(int code, DateTime since) async {
    await fetchType(
      code,
      since,
      probeOnly: true,
      timeout: const Duration(milliseconds: 1500),
    );
    return lastExpected;
  }

  /// Fetch one data type since [since]. Returns decoded samples.
  Future<List<StrapSample>> fetchType(
    int code,
    DateTime since, {
    bool probeOnly = false,
    int maxRounds = 20,
    Duration timeout = const Duration(seconds: 30),
  }) {
    lastExpected = -1;
    final job = _FetchJob(code, since)
      ..probeOnly = probeOnly
      ..maxRounds = maxRounds;
    _job = job;
    _startRound();
    job.timer = Timer(timeout, () {
      if (identical(_job, job)) _finish('history fetch timed out');
    });
    return job.completer.future;
  }

  Future<void> _writeControl(List<int> cmd) async {
    final owner = _job;
    try {
      await writeControl(cmd);
    } on Exception catch (error, stackTrace) {
      AppLog.failure(
        'ble',
        'writing an activity-fetch control command (0x${cmd.first.toRadixString(16)})',
        error,
        stackTrace,
      );
      if (identical(_job, owner)) _finish('control write failed');
    }
  }

  void _startRound() {
    final job = _job;
    if (job == null) return;
    job.data.clear();
    job.lastCounter = -1;
    job.counterGap = false;
    job.rounds++;
    final cmd = <int>[_cmdStartDate, job.code, ...HuamiTime.bytes(job.since)];
    unawaited(_writeControl(cmd));
  }

  /// Control replies arrive here (char `0x0004` notifications).
  void onControl(Uint8List p) {
    final job = _job;
    if (job == null) return;
    if (p.length < 3 || p[0] != _response) {
      AppLog.warning('ble', 'control non-response (${p.length}B)');
      return;
    }
    final cmd = p[1];
    final status = p[2];
    if (cmd == _cmdStartDate) {
      if (status != 0x01) {
        _finish('start rejected 0x${status.toRadixString(16)}');
        return;
      }
      final parsed = HuamiTime.parseStartDate(p);
      if (parsed == null) {
        _finish('bad start reply');
        return;
      }
      job.roundStart = parsed.start;
      lastExpected = parsed.expected;
      if (!job.probeOnly) {
        AppLog.info(
          'ble',
          'round ${job.rounds}: expect ${parsed.expected} pkts '
              'since ${parsed.start.toIso8601String()}',
        );
      }
      if (parsed.expected == 0 || job.probeOnly) {
        unawaited(_ackThenFinish()); // probe: don't download, just ack-abort
        return;
      }
      unawaited(_writeControl([_cmdFetchData]));
    } else if (cmd == _cmdFetchData) {
      if (status != 0x01) {
        _finish('fetch failed 0x${status.toRadixString(16)}');
        return;
      }
      unawaited(_ackAndParseRound());
    } else if (cmd == _cmdAck) {
      // device's reply to our ack — ignore
    }
  }

  /// Activity data packets arrive here (char `0x0005` notifications).
  void onData(Uint8List value) {
    final job = _job;
    if (job == null || value.isEmpty) return;
    final counter = value[0];
    if (counter != ((job.lastCounter + 1) & 0xFF)) {
      job.counterGap = true;
      AppLog.warning(
        'ble',
        'counter gap got=$counter exp=${(job.lastCounter + 1) & 0xFF}',
      );
    }
    job.lastCounter = counter;
    job.data.add(value.sublist(1));
  }

  Future<void> _ackAndParseRound() async {
    final job = _job;
    if (job == null) return;
    await _writeControl([_cmdAck, _ackKeep]); // KEEP on device
    if (!identical(_job, job)) return;
    if (job.counterGap) {
      if (++job.integrityRetries <= _maxIntegrityRetries) {
        _startRound(); // same cursor, discard this entire round
      } else {
        _finish('packets were missing after two retries');
      }
      return;
    }
    job.integrityRetries = 0;
    final raw = job.data.toBytes();
    job.allRaw.add(raw);
    final samples = ActivityParser.parse(job.code, raw, job.roundStart);
    job.samples.addAll(samples);
    AppLog.info(
      'ble',
      'round ${job.rounds}: ${raw.length}B -> ${samples.length} samples',
    );

    // Workout summaries (0x05) decode via WorkoutParser, not ActivityParser, so
    // the sample-based paging below never triggers. Page by the latest decoded
    // workout time instead — otherwise we only ever get the first (oldest) page.
    if (job.code == 0x05) {
      final wk = WorkoutParser.parseStream(job.allRaw.toBytes());
      if (wk.isNotEmpty) {
        var last = wk.first.start;
        for (final w in wk) {
          if (w.start.isAfter(last)) last = w.start;
        }
        final nextSince = last.add(const Duration(minutes: 1));
        final now = DateTime.now();
        if (nextSince.isBefore(now.subtract(const Duration(seconds: 30))) &&
            nextSince.isAfter(job.since)) {
          AppLog.info(
            'ble',
            'workouts: ${wk.length} so far, paging from '
                '${nextSince.toIso8601String()}',
          );
          if (job.rounds >= job.maxRounds) {
            _finish('history round limit reached');
            return;
          }
          job.since = nextSince;
          _startRound();
          return;
        }
      }
      _finishOk();
      return;
    }

    // paging: continue from just after the last sample, if still in the past
    if (samples.isNotEmpty) {
      final last = samples.last.date;
      final nextSince = last.add(const Duration(minutes: 1));
      final now = DateTime.now();
      if (nextSince.isBefore(now.subtract(const Duration(seconds: 30))) &&
          nextSince.isAfter(job.since)) {
        if (job.rounds >= job.maxRounds) {
          _finish('history round limit reached');
          return;
        }
        job.since = nextSince;
        _startRound();
        return;
      }
    } else if ((job.code == 0x01 || job.code == 0x13) && raw.isNotEmpty) {
      // GAP-SKIP (per-minute activity 0x01 + stress 0x13): an all-0xFF round = minutes
      // the strap allocated but never wrote (a recording freeze, or a feed that went
      // quiet then resumed — e.g. stress Jun-15→Jun-19). There are no samples to
      // advance past, so the pager would STALL forever, never reaching the live data
      // after the gap. Step `since` forward by the round's minute-count to CROSS it
      // (skipping empty minutes loses nothing). Record size: activity 8 B/min, stress
      // 1 B/min.
      final recSize = job.code == 0x13 ? 1 : ((raw.length % 8 == 0) ? 8 : 4);
      final mins = (raw.length ~/ recSize).clamp(1, 1440);
      final nextSince = job.since.add(Duration(minutes: mins));
      final now = DateTime.now();
      if (nextSince.isBefore(now.subtract(const Duration(seconds: 30))) &&
          nextSince.isAfter(job.since)) {
        if (job.rounds >= job.maxRounds) {
          _finish('history round limit reached');
          return;
        }
        job.since = nextSince;
        _startRound();
        return;
      }
    }
    _finishOk();
  }

  Future<void> _ackThenFinish() async {
    final job = _job;
    await _writeControl([_cmdAck, _ackKeep]);
    if (identical(_job, job)) _finishOk();
  }

  void _finishOk() {
    final job = _job;
    if (job == null) return;
    job.timer?.cancel();
    lastRaw = job.allRaw.toBytes();
    _job = null;
    if (!job.completer.isCompleted) job.completer.complete(job.samples);
  }

  void _finish(String reason) {
    final job = _job;
    if (job == null) return;
    if (!job.probeOnly) {
      AppLog.warning('ble', 'finish 0x${job.code.toRadixString(16)}: $reason');
    }
    job.timer?.cancel();
    lastRaw = job.allRaw.toBytes();
    _job = null;
    if (!job.completer.isCompleted) {
      if (job.probeOnly) {
        job.completer.complete(job.samples);
      } else {
        job.completer.completeError(
          FetchException(
            type: job.code,
            reason: reason,
            samples: List.unmodifiable(job.samples),
            raw: lastRaw,
          ),
        );
      }
    }
  }
}

class _FetchJob {
  _FetchJob(this.code, this.since) : roundStart = since;

  final int code;
  DateTime since;
  DateTime roundStart;
  final BytesBuilder data = BytesBuilder();
  final BytesBuilder allRaw = BytesBuilder();
  Timer? timer;
  bool counterGap = false;
  int integrityRetries = 0;
  bool probeOnly = false;
  int maxRounds = 20;
  int lastCounter = -1;
  int rounds = 0;
  final List<StrapSample> samples = [];
  final Completer<List<StrapSample>> completer = Completer<List<StrapSample>>();
}
