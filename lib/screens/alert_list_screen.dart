import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/utils/alert_colors.dart';
import 'package:uvalert/utils/time_format.dart';

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
///
/// Watches [uvProvider] directly rather than receiving a fixed alert list at
/// construction time, so a data refresh that changes the active alerts while
/// this screen is open (a new one arrives, or one expires) is reflected live
/// instead of showing a stale snapshot from the moment "See more" was
/// tapped. Always shows every alert in [UvData.alerts], regardless of which
/// ones the collapsed banner has dismissed -- dismissal is a banner-only
/// convenience (see `WeatherAlertBanner`), and this screen is meant to be
/// the complete picture a user can always return to.
class AlertListScreen extends ConsumerWidget {
  /// Creates an [AlertListScreen].
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UvData? uvData = ref.watch(uvProvider).value;
    final List<WeatherAlert> alerts = uvData?.alerts ?? const <WeatherAlert>[];
    final int timezoneOffset = uvData?.timezoneOffset ?? 0;

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
    final bool spansMultipleDays =
        localStart.year != localEnd.year ||
        localStart.month != localEnd.month ||
        localStart.day != localEnd.day;
    final String timeWindow = spansMultipleDays
        ? '${formatDate(localStart)} ${formatTime(localStart)} - '
              '${formatDate(localEnd)} ${formatTime(localEnd)}'
        : '${formatTime(localStart)} - ${formatTime(localEnd)}';

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
