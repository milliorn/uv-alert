import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mixin for a [State] that needs to rebuild itself on a fixed interval so
/// time-derived display values (e.g. a relative-time label, or a solar
/// interpolation that depends on the current instant) stay fresh even when
/// no watched provider changes.
///
/// Starts a [Timer.periodic] in [initState] and cancels it in [dispose].
/// Each tick calls [shouldRebuild]; when it returns `true`, [setState] is
/// called with no state change of its own, just to force a rebuild against
/// a fresh `DateTime.now()`.
mixin PeriodicRebuildMixin<T extends StatefulWidget> on State<T> {
  /// How often to rebuild. Implementers provide a fixed interval, e.g.
  /// `Duration(minutes: 1)`.
  Duration get rebuildInterval;

  /// Whether this tick should actually trigger a rebuild. Defaults to
  /// always rebuilding; override to skip ticks when there is nothing to
  /// refresh yet (e.g. no cached data loaded).
  bool shouldRebuild() => true;

  late final Timer _periodicRebuildTimer;

  @override
  void initState() {
    super.initState();
    _periodicRebuildTimer = Timer.periodic(rebuildInterval, (_) {
      if (!shouldRebuild()) return;

      setState(() {});
    });
  }

  @override
  void dispose() {
    _periodicRebuildTimer.cancel();
    super.dispose();
  }
}
