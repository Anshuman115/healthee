/// Date labels. One implementation, so two headers cannot word a day differently.
///
/// Extracted out of `features/today/today_labels.dart` on its second use
/// (Standards §1): Activity and Insights draw the same `.page-header` date as
/// Today, and `features/` may not reach into another feature (Standards §3). The
/// original file re-exports this one, so every existing call site is unchanged
/// and there is still exactly one definition.
library;

/// `2026-08-04` → `TUE · AUG 4`. Legacy's `_prettyDate`.
///
/// Falls back to the raw string uppercased when the date will not parse, which
/// is legacy's own `catch` — an unparseable date is still information, and a
/// blank where a date belongs reads as a broken header.
String prettyDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso.toUpperCase();
  }
  const days = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${days[parsed.weekday - 1]} · ${months[parsed.month - 1]} ${parsed.day}';
}
