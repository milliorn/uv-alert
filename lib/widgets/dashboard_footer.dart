import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';

/// The uv-alert GitHub repository URL, linked from the dashboard footer.
final Uri _githubRepoUri = Uri.parse('https://github.com/milliorn/uv-alert');

/// Number of minutes in an hour, used by [_formatRelativeTime].
const int _minutesPerHour = 60;

/// Number of hours in a day, used by [_formatRelativeTime].
const int _hoursPerDay = 24;

/// Footer shown at the bottom of the dashboard screen, displaying when the
/// UV data was last updated, the current location, a link to the project's
/// GitHub repository, and a copyright notice.
///
/// Only covers the "fresh data" state -- renders nothing for the
/// last-updated/location line when `uvProvider` has no cached value yet.
/// The stale-data warning variant is a separate, not-yet-implemented
/// feature.
class DashboardFooter extends ConsumerWidget {
  /// Creates a [DashboardFooter].
  const DashboardFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UvData? uvData = ref.watch(uvProvider).value;
    final String? manualLocation = ref
        .watch(settingsProvider)
        .value
        ?.manualLocation;

    final ThemeData theme = Theme.of(context);
    final TextStyle? mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          if (uvData != null)
            Text(
              _updatedLabel(uvData.fetchedAt, manualLocation),
              style: mutedStyle,
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => unawaited(launchUrl(_githubRepoUri)),
            child: const Text('GitHub'),
          ),
          Text('© ${DateTime.now().year} UV Alert', style: mutedStyle),
        ],
      ),
    );
  }
}

/// Builds the "Updated {relative} · {City, State}" label, omitting the
/// location segment entirely when [manualLocation] is `null`.
String _updatedLabel(DateTime fetchedAt, String? manualLocation) {
  final String relative = _formatRelativeTime(fetchedAt);
  final String? cityState = _cityState(manualLocation);

  return cityState == null
      ? 'Updated $relative'
      : 'Updated $relative · $cityState';
}

/// Formats [fetchedAt] (UTC) relative to now, e.g. "just now", "5 min ago",
/// "3 hr ago", "2 d ago".
String _formatRelativeTime(DateTime fetchedAt) {
  final Duration elapsed = DateTime.now().toUtc().difference(fetchedAt);

  if (elapsed.inMinutes < 1) return 'just now';
  
  if (elapsed.inMinutes < _minutesPerHour) {
    return '${elapsed.inMinutes} min ago';
  }

  if (elapsed.inHours < _hoursPerDay) return '${elapsed.inHours} hr ago';

  return '${elapsed.inDays} d ago';
}

/// Derives a "City, State" (or "City, Country" when there is no state)
/// string from a geocoded display name like "Fresno, CA, US" or
/// "Tokyo, Japan". Returns `null` when [manualLocation] is `null`.
///
/// The geocoding API always produces a 3-segment display name when a state
/// is present, or 2 segments otherwise. Taking the first two segments
/// therefore yields "City, State" whenever a state exists, and a sensible
/// "City, Country" fallback otherwise.
String? _cityState(String? manualLocation) {
  if (manualLocation == null) return null;

  final List<String> segments = manualLocation.split(', ');
  return segments.take(2).join(', ');
}
