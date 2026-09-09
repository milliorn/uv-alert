import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/utils/time_format.dart';

/// Horizontal padding around the dashboard footer's content.
const double dashboardFooterPaddingHorizontal = 16;

/// Vertical padding around the dashboard footer's content.
const double dashboardFooterPaddingVertical = 12;

/// How often the "Updated X ago" label re-renders itself so it stays
/// accurate while the dashboard is left open without any provider change.
const Duration _relativeTimeRefreshInterval = Duration(minutes: 1);

/// Number of minutes in an hour, used by [_formatRelativeTime].
const int _minutesPerHour = 60;

/// Minimum width and height (in density-independent pixels) for a tappable
/// element, per ADR 0011's accessibility touch-target requirement.
const double _minTouchTargetDp = 48;

/// Text color for the stale-data warning variant of the updated line, per
/// `.private/architecture/SCREENS.md`'s "amber/yellow" spec. No existing
/// theme token covers this (`ColorScheme` has no warning color), so this
/// uses a fixed Material amber shade directly rather than inventing a new
/// theme-wide token for a single, non-error warning state.
const Color _staleWarningColor = Colors.amber;

/// Footer shown at the bottom of the dashboard screen, displaying when the
/// UV data was last updated, the current location, a link to the project's
/// GitHub repository, and a copyright notice.
///
/// Renders the last-updated/location line whenever `uvProvider` has a
/// cached value. Staleness (`data.fetchedAt` older than [cacheMaxAgeHours])
/// switches the line to "Last updated {date/time} · Data may be outdated"
/// in [_staleWarningColor] instead of the muted fresh-data style -- this is
/// a non-blocking, informational warning: the user can still see and
/// interact with the stale cached data underneath.
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
    _relativeTimeTimer = Timer.periodic(_relativeTimeRefreshInterval, (_) {
      if (ref.read(uvProvider).value == null) return;

      setState(() {});
    });
  }

  @override
  void dispose() {
    _relativeTimeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UvData? uvData = ref.watch(uvProvider).value;
    final String? manualLocationName = ref
        .watch(settingsProvider)
        .value
        ?.manualLocation
        ?.name;

    final ThemeData theme = Theme.of(context);
    final TextStyle? mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle? staleStyle = theme.textTheme.bodySmall?.copyWith(
      color: _staleWarningColor,
    );
    final bool isStale = uvData != null && _isStale(uvData.fetchedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: dashboardFooterPaddingHorizontal,
        vertical: dashboardFooterPaddingVertical,
      ),
      child: Column(
        children: <Widget>[
          if (uvData != null)
            Text(
              isStale
                  ? _staleLabel(uvData.fetchedAt)
                  : _updatedLabel(uvData.fetchedAt, manualLocationName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isStale ? staleStyle : mutedStyle,
            ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(_minTouchTargetDp, _minTouchTargetDp),
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

/// Whether [fetchedAt] (UTC) has exceeded [cacheMaxAgeHours] -- the same
/// threshold and the same server-provided timestamp `Cache.isStale` checks,
/// applied directly to the value already on hand here rather than reading
/// `cacheProvider` (an extra async indirection this otherwise-synchronous
/// widget doesn't need for a value it already has).
bool _isStale(DateTime fetchedAt) =>
    DateTime.now().toUtc().difference(fetchedAt) >=
    const Duration(hours: cacheMaxAgeHours);

/// Builds the "Last updated {date/time} · Data may be outdated" label shown
/// when [fetchedAt] is stale.
String _staleLabel(DateTime fetchedAt) =>
    'Last updated ${_formatDateTime(fetchedAt)} · Data may be outdated';

/// Abbreviated month names for [_formatDateTime], indexed by
/// [DateTime.month] (1-12); index 0 is unused padding so the array can be
/// indexed directly without an off-by-one subtraction at each call site.
const List<String> _monthAbbreviations = <String>[
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

/// Formats [utc] (converted to the device's local time) as e.g.
/// "Jun 1, 2:00 PM". No `intl` dependency is used elsewhere in this codebase
/// for date formatting (only [formatTime] for time-of-day), so this follows
/// the same hand-rolled convention rather than introducing one for a single
/// label.
String _formatDateTime(DateTime utc) {
  final DateTime local = utc.toLocal();
  final String month = _monthAbbreviations[local.month];

  return '$month ${local.day}, ${formatTime(local)}';
}

/// Formats [fetchedAt] (UTC) relative to now, e.g. "just now", "5 mins ago",
/// "23 hr ago".
///
/// Never reaches a day-scale result in practice: `build()` only calls this
/// for non-stale data (see [_isStale]), and staleness is defined as
/// [fetchedAt] being at least [cacheMaxAgeHours] hours old -- the same
/// threshold this function's hour branch caps out just under. A caller that
/// bypassed that guard and passed a [fetchedAt] a day or more old would
/// still get a (merely less specific) "N hr ago" result rather than a
/// crash, since the hour branch has no upper bound of its own.
String _formatRelativeTime(DateTime fetchedAt) {
  final Duration elapsed = DateTime.now().toUtc().difference(fetchedAt);

  if (elapsed.inMinutes < 1) return 'just now';

  if (elapsed.inMinutes < _minutesPerHour) {
    return '${elapsed.inMinutes} mins ago';
  }

  return '${elapsed.inHours} hr ago';
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
