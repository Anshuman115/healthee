import 'package:healthee/data/challenges/challenge.dart';

class ChallengeFeed {
  const ChallengeFeed({
    required this.active,
    required this.suggested,
    required this.recent,
    required this.maxActive,
  });
  factory ChallengeFeed.fromJson(Map<String, Object?> json) => ChallengeFeed(
    active: _list(json['active']),
    suggested: _list(json['suggested']),
    recent: _list(json['recent']),
    maxActive: (json['max_active']! as num).toInt(),
  );
  static List<Challenge> _list(Object? data) => [
    for (final row in data! as List<Object?>)
      Challenge.fromJson(row! as Map<String, Object?>),
  ];
  final List<Challenge> active;
  final List<Challenge> suggested;
  final List<Challenge> recent;
  final int maxActive;
  Challenge? find(int id) =>
      [...active, ...suggested, ...recent].where((c) => c.id == id).firstOrNull;
}
