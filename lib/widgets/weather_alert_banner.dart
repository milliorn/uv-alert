import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/utils/alert_colors.dart';
import 'package:uvalert/utils/alert_severity.dart';

/// Maximum lines shown for the alert description before truncating with an
/// ellipsis, so an unusually long alert body can't grow the banner enough to
/// crowd out the rest of the dashboard.
const int _descriptionMaxLines = 3;

/// A dismissible banner shown below the app bar when one or more active
/// government weather alerts exist.
///
/// Watches [uvProvider] directly rather than receiving alert data as a
/// constructor parameter (the same pattern [AlertListScreen] uses), so the
/// two screens can never disagree about which alerts or which timezone
/// offset are current.
///
/// Renders nothing when there are no active alerts. When there is exactly
/// one, shows its event name and description directly (the pre-#99
/// behavior). When there is more than one, shows a collapsed summary --
/// "N Active Alerts · {top alert's event}" -- where the top alert is chosen
/// by [topAlert] (severity-ranked: Warning > Watch > Advisory). A "See more"
/// action opens [AlertListScreen] with the full, untruncated list.
///
/// Dismissal is local, in-memory state, tracked per-alert by
/// [WeatherAlert.id] (a [Set]) rather than a single value: dismissing one
/// set of alerts does not hide a different, still-active alert that arrives
/// afterward, and a renewed alert that reuses an old id while genuinely
/// representing new information is out of scope here (the id is derived
/// from `senderName`/`event`/`start`, so a change to any of those already
/// produces a new id). The dismiss action always clears every
/// currently-visible alert at once, not just the top-ranked one shown in
/// the collapsed title -- there is no per-alert dismiss affordance in the
/// collapsed view, since it only ever names one alert at a time.
///
/// Built on [MaterialBanner] embedded directly in the widget tree (not
/// shown via `ScaffoldMessenger.showMaterialBanner`), so it renders inline
/// below the app bar and pushes the rest of the dashboard down, rather than
/// floating on top of it.
class WeatherAlertBanner extends ConsumerStatefulWidget {
  /// Creates a [WeatherAlertBanner].
  const WeatherAlertBanner({super.key});

  @override
  ConsumerState<WeatherAlertBanner> createState() => _WeatherAlertBannerState();
}

class _WeatherAlertBannerState extends ConsumerState<WeatherAlertBanner> {
  // A refresh that briefly reports "no active alerts" before the same alert
  // reappears must not resurface a banner the user already dismissed
  // (mirrors the single-alert version's _dismissedAlert, which for the same
  // reason compared against its own prior value rather than oldWidget.alert)
  // -- so pruning below only ever runs against a non-empty new alerts list.
  // An empty update is deliberately treated as "unknown, possibly
  // transient" rather than "these alerts are gone," so a dismissed id
  // survives an empty update and is only dropped once a later non-empty
  // update confirms its alert is genuinely no longer present.
  final Set<String> _dismissedIds = <String>{};

  // The alerts list last used to prune _dismissedIds, so a provider
  // rebuild unrelated to alerts changing (e.g. some other field on UvData
  // updating) doesn't redo that work every time.
  List<WeatherAlert>? _lastPrunedAgainst;

  void _pruneDismissedIds(List<WeatherAlert> alerts) {
    if (_dismissedIds.isEmpty ||
        alerts.isEmpty ||
        identical(alerts, _lastPrunedAgainst)) {
      return;
    }

    _lastPrunedAgainst = alerts;
    final Set<String> currentIds = alerts.map((WeatherAlert a) => a.id).toSet();

    _dismissedIds.retainAll(currentIds);
  }

  void _onDismissAll(List<WeatherAlert> visible) {
    setState(() {
      _dismissedIds.addAll(visible.map((WeatherAlert a) => a.id));
    });
  }

  List<WeatherAlert> _visibleAlerts(List<WeatherAlert> alerts) {
    if (_dismissedIds.isEmpty) return alerts;

    return alerts
        .where((WeatherAlert a) => !_dismissedIds.contains(a.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<WeatherAlert> alerts =
        ref.watch(uvProvider).value?.alerts ?? const <WeatherAlert>[];

    _pruneDismissedIds(alerts);

    final List<WeatherAlert> visible = _visibleAlerts(alerts);

    if (visible.isEmpty) return const SizedBox.shrink();

    final WeatherAlert top = topAlert(visible);
    final bool isMultiple = visible.length > 1;

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String title = isMultiple
        ? '${visible.length} Active Alerts · ${top.event}'
        : top.event;
    final String semanticLabel = '$title. ${top.description}';

    return MaterialBanner(
      backgroundColor: colors.alertBackground,
      leading: ExcludeSemantics(
        child: Icon(Icons.warning_amber, color: colors.alertForeground),
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
                  color: colors.alertForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                top.description,
                maxLines: _descriptionMaxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.alertForeground,
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
              MaterialPageRoute<void>(builder: (_) => const AlertListScreen()),
            );
          },
          child: Text(
            'See more',
            style: TextStyle(color: colors.alertForeground),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.alertForeground),
          tooltip: isMultiple ? 'Dismiss all alerts' : 'Dismiss alert',
          onPressed: () => _onDismissAll(visible),
        ),
      ],
    );
  }
}
