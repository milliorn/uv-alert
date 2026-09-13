import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/services/uv_interpolation.dart';
import 'package:uvalert/widgets/uv_current_display.dart';
import 'package:uvalert/widgets/uv_hero_conditional_line.dart';

/// How often the hero re-renders itself so [interpolatedUvi] and
/// [solarEventTimes] stay current between polls, matching
/// `DashboardFooter`'s `_relativeTimeRefreshInterval` precedent.
const Duration _interpolationRefreshInterval = Duration(minutes: 1);

/// The dashboard's central hero section: the interpolated current-UV ring
/// ([UvCurrentDisplay]) plus the next-event conditional line
/// ([UvHeroConditionalLine]), both driven by `uvProvider`'s cached
/// [UvData] and `locationProvider`'s coordinates.
///
/// Rebuilds on a [Timer.periodic] (like `DashboardFooter`) purely to
/// recompute the interpolated value and solar event times against a fresh
/// "now" (this never triggers a network fetch, only a re-render from
/// already-cached state).
class DashboardHero extends ConsumerStatefulWidget {
  /// Creates a [DashboardHero].
  const DashboardHero({super.key});

  @override
  ConsumerState<DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends ConsumerState<DashboardHero> {
  late final Timer _interpolationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _interpolationRefreshTimer = Timer.periodic(
      _interpolationRefreshInterval,
      (_) {
        if (ref.read(uvProvider).value == null) return;

        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _interpolationRefreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UvData? uvData = ref.watch(uvProvider).value;
    final LocationState location = ref.watch(locationProvider);

    if (uvData == null) return const SizedBox.shrink();

    final DateTime nowUtc = DateTime.now().toUtc();
    final double uvIndex = location == null
        ? uvData.currentUvi
        : interpolatedUvi(
            data: uvData,
            lat: location.lat,
            lon: location.lon,
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
              date: nowUtc,
            ),
            uvData: uvData,
          ),
      ],
    );
  }
}
