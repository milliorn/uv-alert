import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/services/uv_interpolation.dart';
import 'package:uvalert/utils/time_format.dart';
import 'package:uvalert/widgets/periodic_rebuild.dart';
import 'package:uvalert/widgets/uv_current_display.dart';
import 'package:uvalert/widgets/uv_hero_conditional_line.dart';

/// The dashboard's central hero section: the interpolated current-UV ring
/// ([UvCurrentDisplay]) plus the next-event conditional line
/// ([UvHeroConditionalLine]), both driven by `uvProvider`'s cached
/// [UvData] and `locationProvider`'s coordinates.
///
/// Rebuilds on a fixed interval (see [PeriodicRebuildMixin]) purely to
/// recompute [displayUvi] and [solarEventTimes] against a fresh "now" (this
/// never triggers a network fetch, only a re-render from already-cached
/// state).
class DashboardHero extends ConsumerStatefulWidget {
  /// Creates a [DashboardHero].
  const DashboardHero({super.key});

  @override
  ConsumerState<DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends ConsumerState<DashboardHero>
    with PeriodicRebuildMixin<DashboardHero> {
  @override
  Duration get rebuildInterval => const Duration(minutes: 1);

  @override
  bool shouldRebuild() => ref.read(uvProvider).value != null;

  @override
  Widget build(BuildContext context) {
    final UvData? uvData = ref.watch(uvProvider).value;
    final LocationState location = ref.watch(locationProvider);

    if (uvData == null) return const SizedBox.shrink();

    final DateTime nowUtc = DateTime.now().toUtc();
    final double uvIndex = displayUvi(
      data: uvData,
      location: location,
      atUtc: nowUtc,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UvCurrentDisplay(uvIndex: uvIndex),
        if (location != null)
          UvHeroConditionalLine(
            now: nowUtc,
            solarEvents: solarEventTimes(
              lat: location.lat,
              lon: location.lon,
              // solarEventTimes reads its own UTC calendar-date fields from
              // this argument, so it needs an instant whose UTC year/month/
              // day already equal the location-local date, which is exactly
              // what toLocationLocal returns (still isUtc, but shifted so
              // its fields read as the local wall-clock date). Passing
              // nowUtc directly would anchor events to nowUtc's own UTC day,
              // which disagrees with the location-local day for any location
              // far enough from UTC (e.g. UTC+10 just after UTC midnight is
              // already tomorrow locally).
              date: toLocationLocal(nowUtc, uvData.timezoneOffset),
            ),
            uvData: uvData,
          ),
      ],
    );
  }
}
