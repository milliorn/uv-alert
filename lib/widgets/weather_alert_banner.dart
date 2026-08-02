import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/utils/weather_alert_priority.dart';

/// Maximum lines shown for the alert description before truncating with an
/// ellipsis, so an unusually long alert body can't grow the banner enough to
/// crowd out the rest of the dashboard.
const int _descriptionMaxLines = 3;

/// A dismissible banner shown below the app bar when one or more active
/// government weather alerts exist.
///
/// Renders nothing when [alerts] is empty, or once every alert in it has
/// been dismissed. When multiple alerts are active, the banner shows the
/// count plus the top-priority alert (see [prioritizedAlerts]) and offers a
/// "See more" action that opens [AlertListScreen] with the full list.
///
/// Dismissal is local, in-memory, per-alert state: dismissing the
/// currently-shown top alert reveals the next-highest-priority one, if any.
/// Because [WeatherAlert] equality includes its `start`/`end` window, a
/// renewed alert with identical event/description text but a different
/// window is a distinct value and is never masked by a prior dismissal.
///
/// Built on [MaterialBanner] embedded directly in the widget tree (not
/// shown via `ScaffoldMessenger.showMaterialBanner`), so it renders inline
/// below the app bar and pushes the rest of the dashboard down, rather than
/// floating on top of it.
class WeatherAlertBanner extends StatefulWidget {
  /// Creates a [WeatherAlertBanner] for [alerts], or a hidden banner when
  /// [alerts] is empty.
  const WeatherAlertBanner({this.alerts = const <WeatherAlert>[], super.key});

  /// The active alerts to display, if any.
  final List<WeatherAlert> alerts;

  @override
  State<WeatherAlertBanner> createState() => _WeatherAlertBannerState();
}

class _WeatherAlertBannerState extends State<WeatherAlertBanner> {
  final Set<WeatherAlert> _dismissed = <WeatherAlert>{};

  @override
  Widget build(BuildContext context) {
    final List<WeatherAlert> visible = prioritizedAlerts(
      widget.alerts.where((WeatherAlert a) => !_dismissed.contains(a)).toList(),
    );

    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    final WeatherAlert top = visible.first;
    final String headline =
        '${visible.length} Active Alert${visible.length == 1 ? '' : 's'} '
        '· ${top.event}';

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      leading: ExcludeSemantics(
        child: Icon(Icons.warning_amber, color: colors.onErrorContainer),
      ),
      content: Semantics(
        liveRegion: true,
        label: '$headline. ${top.description}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                top.description,
                maxLines: _descriptionMaxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AlertListScreen(alerts: visible),
                ),
              ),
            );
          },
          child: const Text('See more'),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.onErrorContainer),
          tooltip: 'Dismiss alert',
          onPressed: () => setState(() => _dismissed.add(top)),
        ),
      ],
    );
  }
}
