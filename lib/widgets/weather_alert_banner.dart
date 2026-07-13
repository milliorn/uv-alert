import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';

/// Maximum lines shown for the alert description before truncating with an
/// ellipsis, so an unusually long alert body can't grow the banner enough to
/// crowd out the rest of the dashboard.
const int _descriptionMaxLines = 3;

/// A dismissible banner shown below the app bar when an active government
/// weather alert exists.
///
/// Renders nothing when [alert] is `null`. Dismissal is local, in-memory
/// state: once dismissed, the banner stays hidden until a *different*
/// [WeatherAlert] (by value) is passed in, at which point it reappears.
///
/// Built on [MaterialBanner] embedded directly in the widget tree (not
/// shown via `ScaffoldMessenger.showMaterialBanner`), so it renders inline
/// below the app bar and pushes the rest of the dashboard down, rather than
/// floating on top of it.
class WeatherAlertBanner extends StatefulWidget {
  /// Creates a [WeatherAlertBanner] for [alert], or a hidden banner when
  /// [alert] is `null`.
  const WeatherAlertBanner({required this.alert, super.key});

  /// The active alert to display, or `null` if there is none.
  final WeatherAlert? alert;

  @override
  State<WeatherAlertBanner> createState() => _WeatherAlertBannerState();
}

class _WeatherAlertBannerState extends State<WeatherAlertBanner> {
  WeatherAlert? _dismissedAlert;

  @override
  void didUpdateWidget(WeatherAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare against _dismissedAlert itself (not oldWidget.alert): a
    // newly arrived alert that differs from whatever was last dismissed
    // must reappear, even after intervening rebuilds -- including a
    // transient null (e.g. a refresh that briefly reports no active
    // alert). Comparing against oldWidget.alert instead would clear the
    // dismissed marker on the null->same-alert transition, incorrectly
    // resurfacing a banner the user already dismissed.
    final WeatherAlert? newAlert = widget.alert;

    if (newAlert != null && newAlert != _dismissedAlert) {
      _dismissedAlert = null;
    }
  }

  void _onDismiss() {
    setState(() => _dismissedAlert = widget.alert);
  }

  @override
  Widget build(BuildContext context) {
    final WeatherAlert? alert = widget.alert;
    
    if (alert == null || alert == _dismissedAlert) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      leading: ExcludeSemantics(
        child: Icon(Icons.warning_amber, color: colors.onErrorContainer),
      ),
      content: Semantics(
        liveRegion: true,
        label: '${alert.event}. ${alert.description}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                alert.event,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                alert.description,
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
        IconButton(
          icon: Icon(Icons.close, color: colors.onErrorContainer),
          tooltip: 'Dismiss alert',
          onPressed: _onDismiss,
        ),
      ],
    );
  }
}
