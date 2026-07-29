import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_flutter/ui/screens/tasks/task_time_formatter.dart';

void main() {
  test('formats second timestamps as local date and time', () {
    final formatted = formatTaskLastRun('1710000000');
    expect(
      formatted,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')),
    );
  });

  test('formats millisecond timestamps as local date and time', () {
    expect(formatTaskLastRun('1710000000000'), formatTaskLastRun('1710000000'));
  });

  test('formats ISO date strings and keeps invalid values readable', () {
    expect(formatTaskLastRun('2026-07-29T08:09:10Z'), contains('2026-07-29'));
    expect(formatTaskLastRun('already formatted'), 'already formatted');
  });

  test('hides empty and zero timestamps', () {
    expect(formatTaskLastRun(null), isEmpty);
    expect(formatTaskLastRun(''), isEmpty);
    expect(formatTaskLastRun('0'), isEmpty);
  });
}
