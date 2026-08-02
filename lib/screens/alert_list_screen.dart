import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';

/// Horizontal padding around the alert list's content.
const double _alertListPaddingHorizontal = 16;

/// Vertical padding around the alert list's content.
const double _alertListPaddingVertical = 8;

/// Vertical gap between an alert's fields within a single list item.
const double _alertItemFieldGap = 4;

/// Number of hours on a 12-hour clock face, used by [_hm] to convert a
/// 24-hour hour-of-day into 12-hour form.
const int _hoursPerHalfDay = 12;

/// Month abbreviations, 1-indexed (index 0 is unused) so [_monthAbbr] can
/// index directly by [DateTime.month].
const List<String> _monthAbbrs = <String>[
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Full-screen list of every currently-active [WeatherAlert], with
/// untruncated details (event, full description, sender, time window).
///
/// Reached via a normal (non-modal) route push from the dashboard's
/// weather alert banner's "See more" action, so it gets its own back-stack
/// entry and is revisitable via the system back button.
class AlertListScreen extends StatelessWidget {
  /// Creates an [AlertListScreen] listing [alerts].
  const AlertListScreen({required this.alerts, super.key});

  /// The alerts to display, in the order they should be shown.
  final List<WeatherAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Active Alerts')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: _alertListPaddingHorizontal,
          vertical: _alertListPaddingVertical,
        ),
        itemCount: alerts.length,
        separatorBuilder: (BuildContext context, int index) => const Divider(),
        itemBuilder: (BuildContext context, int index) {
          final WeatherAlert alert = alerts[index];

          return Padding(
            key: ValueKey<String>(
              '${alert.event}|${alert.start.toIso8601String()}|'
              '${alert.end.toIso8601String()}',
            ),
            padding: const EdgeInsets.symmetric(
              vertical: _alertListPaddingVertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(alert.event, style: theme.textTheme.titleMedium),
                const SizedBox(height: _alertItemFieldGap),
                Text(alert.description),
                const SizedBox(height: _alertItemFieldGap),
                Text(
                  'Issued by ${alert.senderName}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: _alertItemFieldGap),
                Text(
                  _formatTimeWindow(alert.start, alert.end),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Formats the [start]-[end] window as e.g.
/// "Aug 2, 2:00 PM – Aug 3, 8:00 AM".
String _formatTimeWindow(DateTime start, DateTime end) {
  return '${_monthAbbr(start.month)} ${start.day}, ${_hm(start)} – '
      '${_monthAbbr(end.month)} ${end.day}, ${_hm(end)}';
}

/// Returns the 3-letter English abbreviation for [month] (1-12).
String _monthAbbr(int month) => _monthAbbrs[month];

/// Formats [dt]'s time-of-day in 12-hour clock form, e.g. "2:00 PM".
String _hm(DateTime dt) {
  final int hour24 = dt.hour;
  final int hour12 = hour24 % _hoursPerHalfDay == 0
      ? _hoursPerHalfDay
      : hour24 % _hoursPerHalfDay;
  final String minute = dt.minute.toString().padLeft(2, '0');
  final String period = hour24 < _hoursPerHalfDay ? 'AM' : 'PM';

  return '$hour12:$minute $period';
}
