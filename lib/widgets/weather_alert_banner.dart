import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/utils/alert_severity.dart';

/// Maximum lines shown for the alert description before truncating with an
/// ellipsis, so an unusually long alert body can't grow the banner enough to
/// crowd out the rest of the dashboard.
const int _descriptionMaxLines = 3;

/// A dismissible banner shown below the app bar when one or more active
/// government weather alerts exist.
///
/// Renders nothing when [alerts] is empty. When there is exactly one active
/// alert, shows its event name and description directly (the pre-#99
/// behavior). When there is more than one, shows a collapsed summary --
/// "N Active Alerts · {top alert's event}" -- where the top alert is chosen
/// by [topAlert] (severity-ranked: Warning > Watch > Advisory). A "See more"
/// action opens [AlertListScreen] with the full, untruncated list.
///
/// Dismissal is local, in-memory state, tracked per-alert by
/// [WeatherAlert.id] (a [Set]) rather than a single value: dismissing one
/// alert does not hide a different, still-active alert, and a renewed alert
/// that reuses an old id while genuinely representing new information is
/// out of scope here (the id is derived from `senderName`/`event`/`start`,
/// so a change to any of those already produces a new id).
///
/// Built on [MaterialBanner] embedded directly in the widget tree (not
/// shown via `ScaffoldMessenger.showMaterialBanner`), so it renders inline
/// below the app bar and pushes the rest of the dashboard down, rather than
/// floating on top of it.
class WeatherAlertBanner extends StatefulWidget {
  /// Creates a [WeatherAlertBanner] for [alerts], or a hidden banner when
  /// [alerts] is empty.
  const WeatherAlertBanner({required this.alerts, super.key});

  /// The active alerts to display. An empty list renders nothing.
  final List<WeatherAlert> alerts;

  @override
  State<WeatherAlertBanner> createState() => _WeatherAlertBannerState();
}

class _WeatherAlertBannerState extends State<WeatherAlertBanner> {
  final Set<String> _dismissedIds = <String>{};

  @override
  void didUpdateWidget(WeatherAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop dismissed ids that are no longer active, so the set doesn't grow
    // unboundedly across a long dashboard session, and so an id that later
    // gets reused (extremely unlikely given how id is synthesized, but not
    // impossible) doesn't inherit a stale dismissal.
    final Set<String> activeIds = widget.alerts
        .map((WeatherAlert a) => a.id)
        .toSet();
    _dismissedIds.retainAll(activeIds);
  }

  void _onDismiss(String id) {
    setState(() => _dismissedIds.add(id));
  }

  List<WeatherAlert> get _visibleAlerts => widget.alerts
      .where((WeatherAlert a) => !_dismissedIds.contains(a.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final List<WeatherAlert> visible = _visibleAlerts;

    if (visible.isEmpty) return const SizedBox.shrink();

    final WeatherAlert top = topAlert(visible);
    final bool isMultiple = visible.length > 1;

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String title = isMultiple
        ? '${visible.length} Active Alerts · ${top.event}'
        : top.event;
    final String semanticLabel = isMultiple
        ? '$title. ${top.description}'
        : '${top.event}. ${top.description}';

    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      leading: ExcludeSemantics(
        child: Icon(Icons.warning_amber, color: colors.onErrorContainer),
      ),
      content: Semantics(
        liveRegion: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
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
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlertListScreen(alerts: visible),
              ),
            );
          },
          child: Text(
            'See more',
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.onErrorContainer),
          tooltip: 'Dismiss alert',
          onPressed: () => _onDismiss(top.id),
        ),
      ],
    );
  }
}
