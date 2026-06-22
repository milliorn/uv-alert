import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uvalert/api/geocoding_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const int _locationScreenIndex = 1;

const double _sectionGap = 24;
const double _itemGap = 12;
const double _spinnerSize = 16;
const double _spinnerStrokeWidth = 2;

// ---------------------------------------------------------------------------
// Confirm result
// ---------------------------------------------------------------------------

/// Bundles the resolved location with how it was obtained.
///
/// Stored as a single nullable field so the two values can never desync;
/// both are set together when transitioning to [_Phase.confirm] and cleared
/// together when the user changes location.
typedef _ConfirmResult = ({GeocodingResult result, bool fromGps});

// ---------------------------------------------------------------------------
// Internal state machine
// ---------------------------------------------------------------------------

/// The UI phase this screen is in.
enum _Phase {
  /// Initial view: two option buttons, no result yet.
  /// Also used after an error: _errorMessage drives the error text display.
  idle,

  /// GPS or geocoding request in-flight.
  loading,

  /// A location has been resolved and is shown for user confirmation.
  confirm,

  /// The user chose manual entry; text field is active.
  manual,

  /// Geocoding the manual-entry string.
  geocoding,
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Screen 2 of onboarding: lets the user set their location via GPS or
/// manual entry.
class LocationOnboardingScreen extends ConsumerStatefulWidget {
  /// Creates a [LocationOnboardingScreen].
  ///
  /// [geocodingApi] is injected for testing; defaults to a real instance
  /// constructed from the stored proxy URL when omitted.
  const LocationOnboardingScreen({super.key, GeocodingApi? geocodingApi})
    : _geocodingApi = geocodingApi;

  final GeocodingApi? _geocodingApi;

  @override
  ConsumerState<LocationOnboardingScreen> createState() =>
      _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState
    extends ConsumerState<LocationOnboardingScreen> {
  _Phase _phase = _Phase.idle;
  bool _continuing = false;
  _ConfirmResult? _pending;
  String _errorMessage = '';

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  GeocodingApi? _ownedApi;

  GeocodingApi _geocodingApi(String proxyBaseUrl, String deviceId) =>
      widget._geocodingApi ??
      (_ownedApi ??= GeocodingApi(
        proxyBaseUrl: proxyBaseUrl,
        deviceId: deviceId,
      ));

  @override
  void dispose() {
    _manualController.dispose();
    _manualFocus.dispose();
    _ownedApi?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // GPS flow
  // -------------------------------------------------------------------------

  Future<void> _onUseMyLocation(String proxyBaseUrl, String deviceId) async {
    setState(() {
      _phase = _Phase.loading;
      _errorMessage = '';
    });

    try {
      await ref.read(locationProvider.notifier).fetchGps();

      if (!mounted) return;

      final LocationState loc = ref.read(locationProvider);

      if (loc == null) {
        _setError('Could not read GPS coordinates.');
        return;
      }

      final GeocodingResult result = await _geocodingApi(
        proxyBaseUrl,
        deviceId,
      ).reverseGeocode(lat: loc.lat, lon: loc.lon);

      if (!mounted) return;

      setState(() {
        _pending = (result: result, fromGps: true);
        _phase = _Phase.confirm;
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      // Permission denied; fall through to manual entry.
      setState(() => _phase = _Phase.manual);
      _manualFocus.requestFocus();
    } on GeocodingNotFoundException {
      if (!mounted) return;
      _setError('Could not determine your city. Try entering it manually.');
    } on Object {
      if (!mounted) return;
      _setError('Something went wrong. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // Manual entry flow
  // -------------------------------------------------------------------------

  void _onEnterManually() {
    setState(() {
      _phase = _Phase.manual;
      _errorMessage = '';
    });
    _manualFocus.requestFocus();
  }

  Future<void> _onGeocodeManual(String proxyBaseUrl, String deviceId) async {
    final String query = _manualController.text.trim();

    if (query.isEmpty) return;

    setState(() {
      _phase = _Phase.geocoding;
      _errorMessage = '';
    });

    try {
      final GeocodingResult result = await _geocodingApi(
        proxyBaseUrl,
        deviceId,
      ).geocode(query);

      if (!mounted) return;

      setState(() {
        _pending = (result: result, fromGps: false);
        _phase = _Phase.confirm;
      });
    } on GeocodingNotFoundException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.manual;
        _errorMessage =
            'Location not found. Try city only'
            ' (e.g. "London") or with full country name'
            ' (e.g. "London, England").';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.manual;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  // -------------------------------------------------------------------------
  // Confirm / continue
  // -------------------------------------------------------------------------

  Future<void> _onConfirm() async {
    setState(() => _continuing = true);

    assert(_pending != null, '_onConfirm called outside confirm phase');

    final _ConfirmResult confirmed = _pending!;

    try {
      await ref
          .read(settingsProvider.notifier)
          .setManualLocation(confirmed.result.displayName);

      await ref
          .read(settingsProvider.notifier)
          .setUseGps(value: confirmed.fromGps);

      ref
          .read(locationProvider.notifier)
          .setManual(lat: confirmed.result.lat, lon: confirmed.result.lon);

      if (!mounted) return;

      ref.invalidate(preferencesProvider);

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationOnboardingScreen(),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _continuing = false;
        _phase = _Phase.confirm;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _onChangeLocation() {
    setState(() {
      _phase = _Phase.manual;
      _pending = null;
      _errorMessage = '';
    });
    _manualFocus.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _setError(String message) {
    setState(() {
      _phase = _Phase.idle;
      _errorMessage = message;
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final String proxyBaseUrl = ref.watch(proxyBaseUrlProvider);
    // Null until deviceIdProvider resolves; callbacks that trigger network
    // calls are disabled while null to prevent an empty X-Device-ID header.
    final String? deviceId = ref.watch(deviceIdProvider).value;

    final VoidCallback? onGpsPressed = deviceId == null
        ? null
        : () => _onUseMyLocation(proxyBaseUrl, deviceId);

    final VoidCallback? onManualSearch = deviceId == null
        ? null
        : () => _onGeocodeManual(proxyBaseUrl, deviceId);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingPaddingHorizontal,
            vertical: onboardingPaddingVertical,
          ),
          child: Column(
            spacing: _sectionGap,
            children: <Widget>[
              const Spacer(),

              const _Header(),

              if (_phase == _Phase.idle) ...<Widget>[
                _GpsButton(onPressed: onGpsPressed),
                _ManualButton(onPressed: _onEnterManually),
              ],

              if (_phase == _Phase.loading)
                const CircularProgressIndicator.adaptive(),

              if (_phase == _Phase.manual || _phase == _Phase.geocoding)
                _ManualEntryField(
                  controller: _manualController,
                  focusNode: _manualFocus,
                  loading: _phase == _Phase.geocoding,
                  onSearch: onManualSearch,
                ),

              if (_phase == _Phase.confirm)
                _ConfirmCard(
                  displayName: _pending!.result.displayName,
                  onChange: _onChangeLocation,
                ),

              if (_errorMessage.isNotEmpty) _ErrorText(message: _errorMessage),

              const Spacer(),

              const OnboardingProgressDots(
                current: _locationScreenIndex,
                total: totalOnboardingSteps,
              ),

              // Continue is only shown/enabled in confirm phase.
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_phase == _Phase.confirm && !_continuing)
                      ? _onConfirm
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets (private)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: _itemGap,
      children: <Widget>[
        Text(
          'Your Location',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          'UV Alert uses your location to provide accurate UV readings '
          'for your area.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _GpsButton extends StatelessWidget {
  const _GpsButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.my_location),
        label: const Text('Use My Location'),
      ),
    );
  }
}

class _ManualButton extends StatelessWidget {
  const _ManualButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: const Text('Enter location manually'),
      ),
    );
  }
}

class _ManualEntryField extends StatelessWidget {
  const _ManualEntryField({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  // No onSubmitted parameter: TextField.onSubmitted passes the field value
  // which this widget never uses. The adapter (_) => onSearch!() is derived
  // here from onSearch so the caller stays free of that boilerplate.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !loading,
      textInputAction: TextInputAction.search,
      onSubmitted: onSearch == null ? null : (_) => onSearch!(),
      decoration: InputDecoration(
        hintText: 'City, State (e.g. New York, NY)',
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(_itemGap),
                child: SizedBox.square(
                  dimension: _spinnerSize,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: _spinnerStrokeWidth,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: onSearch,
              ),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.displayName, required this.onChange});

  final String displayName;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(
      onboardingCardBorderRadius,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: onboardingCardPaddingHorizontal,
        vertical: onboardingCardPaddingVertical,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.primary,
          width: onboardingSelectedBorderWidth,
        ),
        color: colors.primary.withValues(alpha: onboardingSelectedCardOpacity),
      ),
      child: Column(
        spacing: _itemGap,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on, color: colors.primary),
              const SizedBox(width: _itemGap),
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(
            'Location is approximate and may vary based on device GPS '
            'accuracy, network conditions, or other factors.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
      textAlign: TextAlign.center,
    );
  }
}
