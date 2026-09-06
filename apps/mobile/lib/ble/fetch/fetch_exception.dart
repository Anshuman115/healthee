import 'dart:typed_data';

import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';

/// A failed stream, carrying only data from completed, intact rounds.
class FetchException extends StrapException {
  /// Partial data may be stored, but must never certify a complete sync.
  FetchException({
    required this.type,
    required String reason,
    required this.samples,
    required this.raw,
  }) : super(StrapFetchFailed(type, reason));

  /// The fetch type that stopped.
  final int type;

  /// Verified samples from earlier rounds. The failed round is excluded.
  final List<StrapSample> samples;

  /// Verified bytes for session and workout parsers.
  final Uint8List raw;
}
