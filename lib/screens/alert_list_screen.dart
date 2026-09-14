import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/utils/time_format.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart' show AlertColors;

// Note: `event`/`description`/`senderName` are display text already, but
// `start`/`end` are UTC instants (see WeatherAlert's doc comments) and must
// be converted via toLocationLocal before formatting -- see _AlertCard.

/// Horizontal padding around each alert card's content.
const double _alertCardPaddingHorizontal = 16;

/// Vertical padding around each alert card's content.
const double _alertCardPaddingVertical = 12;

/// Vertical gap between alert cards in the list.
const double _alertListGap = 8;

/// Gap between an alert card's title and its metadata/description lines.
const double _alertCardSectionGap = 4;

/// Full-screen list of every active government weather alert, with
/// untruncated details -- event, full description, sender, and time window.
///
/// Reached from `WeatherAlertBanner`'s "See more" action. A dedicated
/// [MaterialPageRoute] (own back-stack entry) rather than a modal/bottom
/// sheet, so the list is easy to return to and revisit rather than a
/// one-off glance.
class AlertListScreen extends StatelessWidget {
  /// Creates an [AlertListScreen] listing [alerts].
  const AlertListScreen({
    required this.alerts,
    required this.timezoneOffset,
    super.key,
  });

  /// The alerts to display, in the order given -- callers pass the
  /// currently-visible (non-dismissed) alerts from the banner.
  final List<WeatherAlert> alerts;

  /// The queried location's UTC offset in seconds (`UvData.timezoneOffset`),
  /// used to display each alert's start/end in the location's local time
  /// rather than the viewer's device timezone or raw UTC.
  final int timezoneOffset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Alerts')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: _alertCardPaddingHorizontal,
          vertical: _alertListGap,
        ),
        itemCount: alerts.length,
        separatorBuilder: (_, _) => const SizedBox(height: _alertListGap),
        itemBuilder: (BuildContext context, int index) {
          final WeatherAlert alert = alerts[index];
          return _AlertCard(
            // Keyed on the alert's own stable identity, per issue #99's
            // explicit callout: without a key, Flutter matches list items
            // positionally, so a reorder or count change between rebuilds
            // could silently misattribute one alert's state to another.
            key: ValueKey<String>(alert.id),
            alert: alert,
            timezoneOffset: timezoneOffset,
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.timezoneOffset,
    super.key,
  });

  final WeatherAlert alert;
  final int timezoneOffset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? senderName = alert.senderName;

    final DateTime localStart = toLocationLocal(alert.start, timezoneOffset);
    final DateTime localEnd = toLocationLocal(alert.end, timezoneOffset);
    final String timeWindow =
        '${formatTime(localStart)} - ${formatTime(localEnd)}';

    return Card(
      color: colors.alertBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _alertCardPaddingHorizontal,
          vertical: _alertCardPaddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              alert.event,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.alertForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: _alertCardSectionGap),
            Text(
              senderName == null ? timeWindow : '$senderName · $timeWindow',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.alertForeground,
              ),
            ),
            const SizedBox(height: _alertCardSectionGap),
            Text(
              alert.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.alertForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
