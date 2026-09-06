import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/utils/epoch.dart';

void main() {
  test('fromEpochSeconds converts epoch seconds to a UTC DateTime', () {
    expect(fromEpochSeconds(0), DateTime.utc(1970));
    expect(
      fromEpochSeconds(1700000000),
      DateTime.utc(2023, 11, 14, 22, 13, 20),
    );
  });

  test('fromEpochSeconds returns a UTC DateTime', () {
    expect(fromEpochSeconds(0).isUtc, isTrue);
  });

  test('toEpochSeconds converts a DateTime back to epoch seconds', () {
    expect(toEpochSeconds(DateTime.utc(1970)), 0);
    expect(toEpochSeconds(DateTime.utc(2023, 11, 14, 22, 13, 20)), 1700000000);
  });

  test('toEpochSeconds is the inverse of fromEpochSeconds', () {
    const int seconds = 1700050000;
    expect(toEpochSeconds(fromEpochSeconds(seconds)), seconds);
  });
}
