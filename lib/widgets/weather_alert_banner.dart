import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';

/// Horizontal padding inside the banner.
const double _bannerPaddingHorizontal = 16;

/// Vertical padding inside the banner.
const double _bannerPaddingVertical = 12;

/// Gap between the warning icon and the alert text.
const double _iconTextGap = 12;

/// Gap between the dismiss button and the banner's trailing edge.
const double _dismissButtonGap = 4;

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
    // A newly arrived alert (different from whatever was last dismissed)
    // must reappear even if the user dismissed an earlier one.
    if (widget.alert != oldWidget.alert) {
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

    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _bannerPaddingHorizontal,
          vertical: _bannerPaddingVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(Icons.warning_amber, color: colors.onErrorContainer),
            ),
            const SizedBox(width: _iconTextGap),
            Expanded(
              child: Semantics(
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
            ),
            const SizedBox(width: _dismissButtonGap),
            IconButton(
              icon: Icon(Icons.close, color: colors.onErrorContainer),
              tooltip: 'Dismiss alert',
              onPressed: _onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
