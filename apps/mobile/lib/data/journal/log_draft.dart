import 'package:healthee/data/journal/log_kind.dart';

/// An explicit observation; no guessed body measurements or default doses.
class LogDraft {
  const LogDraft({
    required this.kind,
    required this.at,
    this.amount,
    this.name,
    this.notes,
  });

  final LogKind kind;
  final DateTime at;
  final double? amount;
  final String? name;
  final String? notes;

  String? validate(DateTime now) {
    if (at.isAfter(now)) return 'Choose a time that has already passed.';
    if (kind.needsName && (name?.trim().isEmpty ?? true)) {
      return 'Describe what you want to record.';
    }
    if (!kind.needsName &&
        (amount == null || !amount!.isFinite || amount! <= 0)) {
      return 'Enter an amount greater than zero.';
    }
    if (kind.isDuration && amount != amount?.roundToDouble()) {
      return 'Enter a whole number of minutes.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'type': kind.name,
    'at': at.millisecondsSinceEpoch,
    if (kind.isDuration)
      'minutes': amount?.toInt()
    else if (amount != null)
      'amount': amount,
    if (kind.unit != null) 'unit': kind.unit,
    if (name != null) 'name': name!.trim(),
    if (notes?.trim().isNotEmpty ?? false) 'notes': notes!.trim(),
  };
}
