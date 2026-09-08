class HistoryStatistics {
  HistoryStatistics(List<double> values) {
    if (values.isEmpty) {
      throw ArgumentError('History needs at least one observation');
    }
    final sorted = [...values]..sort();
    minimum = sorted.first;
    maximum = sorted.last;
    mean = values.reduce((a, b) => a + b) / values.length;
    final middle = values.length ~/ 2;
    median = values.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    change = values.last - values.first;
  }
  late final double minimum;
  late final double maximum;
  late final double mean;
  late final double median;
  late final double change;
}
