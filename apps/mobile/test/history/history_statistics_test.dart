import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/history/history_statistics.dart';

void main() {
  test('even-length median averages middle values; real zero is retained', () {
    final statistics = HistoryStatistics([0, 10, 4, 2]);
    expect(statistics.median, 3);
    expect(statistics.mean, 4);
    expect(statistics.minimum, 0);
    expect(statistics.maximum, 10);
    expect(statistics.change, 2);
  });
  test('one observation has no invented movement', () {
    final statistics = HistoryStatistics([12]);
    expect(statistics.median, 12);
    expect(statistics.change, 0);
  });
}
