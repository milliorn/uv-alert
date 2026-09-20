import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/utils/time_format.dart';

void main() {
  group('startOfLocationLocalDayUtc', () {
    test('returns the UTC instant of local midnight for a positive offset', () {
      // UTC+10: 14:00 UTC on June 21st is 00:00 local on June 22nd, so
      // local midnight (the start of that local day) is 14:00 UTC on
      // June 21st. This is the same instant, since it lands exactly on
      // the boundary.
      const int tzOffsetSeconds = 10 * 3600;
      final DateTime nowUtc = DateTime.utc(2024, 6, 21, 14);

      final DateTime result = startOfLocationLocalDayUtc(
        nowUtc,
        tzOffsetSeconds,
      );

      expect(result, DateTime.utc(2024, 6, 21, 14));
      expect(result.isUtc, isTrue);
    });

    test('the location-local day boundary differs from the UTC day boundary '
        'near a UTC-day crossing', () {
      // 23:00 UTC on June 21st is 09:00 local the next day (June 22nd)
      // for UTC+10. This is already a new local day even though the UTC
      // calendar day has not rolled over yet. Local midnight for that
      // local day (June 22nd) is 14:00 UTC on June 21st, one hour before
      // nowUtc, not the UTC calendar day's own midnight (00:00 UTC on
      // June 21st).
      const int tzOffsetSeconds = 10 * 3600;
      final DateTime nowUtc = DateTime.utc(2024, 6, 21, 23);

      final DateTime result = startOfLocationLocalDayUtc(
        nowUtc,
        tzOffsetSeconds,
      );

      expect(result, DateTime.utc(2024, 6, 21, 14));
      expect(result, isNot(DateTime.utc(2024, 6, 21)));
    });

    test('handles a negative offset', () {
      // UTC-7 (Fresno): 03:00 UTC on June 22nd is 20:00 local on June 21st.
      // Local midnight for June 21st is 07:00 UTC that same day.
      const int tzOffsetSeconds = -7 * 3600;
      final DateTime nowUtc = DateTime.utc(2024, 6, 22, 3);

      final DateTime result = startOfLocationLocalDayUtc(
        nowUtc,
        tzOffsetSeconds,
      );

      expect(result, DateTime.utc(2024, 6, 21, 7));
    });

    test('handles a zero offset (UTC)', () {
      final DateTime nowUtc = DateTime.utc(2024, 6, 21, 14, 30);

      final DateTime result = startOfLocationLocalDayUtc(nowUtc, 0);

      expect(result, DateTime.utc(2024, 6, 21));
    });
  });
}
