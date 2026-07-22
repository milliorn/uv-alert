import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';

/// Horizontal padding around the dashboard footer's content.
const double dashboardFooterPaddingHorizontal = 16;

/// Vertical padding around the dashboard footer's content.
const double dashboardFooterPaddingVertical = 12;

/// How often the "Updated X ago" label re-renders itself so it stays
/// accurate while the dashboard is left open without any provider change.
const Duration _relativeTimeRefreshInterval = Duration(minutes: 1);

/// Number of minutes in an hour, used by [_formatRelativeTime].
const int _minutesPerHour = 60;

/// Number of hours in a day, used by [_formatRelativeTime].
const int _hoursPerDay = 24;

/// Minimum width and height (in density-independent pixels) for a tappable
/// element, per ADR 0011's accessibility touch-target requirement.
const double _minTouchTargetDp = 48;

/// Footer shown at the bottom of the dashboard screen, displaying when the
/// UV data was last updated, the current location, a link to the project's
/// GitHub repository, and a copyright notice.
///
/// Renders the last-updated/location line whenever `uvProvider` has a
/// cached value, with no check of how old it is -- there is currently no
/// visual distinction between recently-fetched and long-stale data. A
/// dedicated stale-data warning variant is a separate, not-yet-implemented
/// feature.
class DashboardFooter extends ConsumerStatefulWidget {
  /// Creates a [DashboardFooter].
  const DashboardFooter({super.key});

  @override
  ConsumerState<DashboardFooter> createState() => _DashboardFooterState();
}

class _DashboardFooterState extends ConsumerState<DashboardFooter> {
  late final Timer _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    _relativeTimeTimer = Timer.periodic(
      _relativeTimeRefreshInterval,
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _relativeTimeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: dashboardFooterPaddingHorizontal,
        vertical: dashboardFooterPaddingVertical,
      ),
      child: Column(
        children: <Widget>[
          if (uvData != null)
            Text(
              _updatedLabel(uvData.fetchedAt, manualLocation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mutedStyle,
            ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(
                _minTouchTargetDp,
                _minTouchTargetDp,
              ),
            ),
            onPressed: () => unawaited(_openGithubRepo(context)),
            child: const Text('GitHub'),
          ),
          Text('© ${DateTime.now().year} UV Alert', style: mutedStyle),
        ],
      ),
    );
  }
}

/// Launches the uv-alert GitHub repository, showing a [SnackBar] if the
/// platform reports it could not open a handler for the URL.
Future<void> _openGithubRepo(BuildContext context) async {
  final bool launched = await launchUrl(Uri.parse(githubRepoUrl));

  if (!context.mounted || launched) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Could not open GitHub')));
}

/// Builds the "Updated {relative} · {City, State}" label, omitting the
/// location segment entirely when [manualLocation] is `null` or empty.
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
/// "Tokyo, Japan". Returns `null` when [manualLocation] is `null` or empty.
///
/// The geocoding API always produces a 3-segment, comma-space-delimited
/// display name when a state is present, or 2 segments otherwise. Taking
/// the first two segments therefore yields "City, State" whenever a state
/// exists, and a sensible "City, Country" fallback otherwise. If
/// [manualLocation] doesn't match that shape (e.g. a future format change,
/// or a hand-edited preference), this still returns at most its first two
/// comma-separated segments -- a 1-segment string comes back unchanged,
/// but anything with 3+ segments is truncated, which may drop real data
/// rather than showing it verbatim.
String? _cityState(String? manualLocation) {
  if (manualLocation == null || manualLocation.isEmpty) return null;

  final List<String> segments = manualLocation.split(', ');

  return segments.take(2).join(', ');
}
