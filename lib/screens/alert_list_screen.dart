import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/utils/time_format.dart';

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
/// Reached from [WeatherAlertBanner]'s "See more" action. A dedicated
/// [MaterialPageRoute] (own back-stack entry) rather than a modal/bottom
/// sheet, so the list is easy to return to and revisit rather than a
/// one-off glance.
class AlertListScreen extends StatelessWidget {
  /// Creates an [AlertListScreen] listing [alerts].
  const AlertListScreen({required this.alerts, super.key});

  /// The alerts to display, in the order given -- callers pass the
  /// currently-visible (non-dismissed) alerts from the banner.
  final List<WeatherAlert> alerts;

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
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, super.key});

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? senderName = alert.senderName;

    final String timeWindow =
        '${formatTime(alert.start)} – ${formatTime(alert.end)}';

    return Card(
      color: colors.errorContainer,
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
                color: colors.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: _alertCardSectionGap),
            Text(
              senderName == null ? timeWindow : '$senderName · $timeWindow',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
            const SizedBox(height: _alertCardSectionGap),
            Text(
              alert.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
