/// User observations supported by the canonical manual-log endpoint.
enum LogKind {
  caffeine('Caffeine', 'mg'),
  alcohol('Alcohol', 'units'),
  meditation('Meditation', 'min'),
  exercise('Exercise', 'min'),
  weight('Weight', 'kg'),
  habit('Habit', null),
  water('Water', 'ml'),
  mood('Mood', null),
  symptom('Symptom', null);

  const LogKind(this.label, this.unit);
  final String label;
  final String? unit;
  bool get isDuration => unit == 'min';
  bool get needsName => unit == null;
}
