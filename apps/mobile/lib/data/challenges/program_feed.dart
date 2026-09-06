import 'package:healthee/data/challenges/health_program.dart';

class ProgramFeed {
  const ProgramFeed({
    required this.active,
    required this.suggested,
    required this.recent,
  });
  factory ProgramFeed.fromJson(Map<String, Object?> json) => ProgramFeed(
    active: json['active'] == null
        ? null
        : HealthProgram.fromJson(json['active']! as Map<String, Object?>),
    suggested: _list(json['suggested']),
    recent: _list(json['recent']),
  );
  static List<HealthProgram> _list(Object? data) => [
    for (final row in data! as List<Object?>)
      HealthProgram.fromJson(row! as Map<String, Object?>),
  ];
  final HealthProgram? active;
  final List<HealthProgram> suggested;
  final List<HealthProgram> recent;
  HealthProgram? find(int id) => [
    ?active,
    ...suggested,
    ...recent,
  ].where((program) => program.id == id).firstOrNull;
}
