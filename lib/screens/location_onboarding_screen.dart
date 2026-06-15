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
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const int _locationScreenIndex = 1;

const double _screenPaddingHorizontal = onboardingPaddingHorizontal;
const double _screenPaddingVertical = onboardingPaddingVertical;

const double _sectionGap = 24;
const double _itemGap = 12;

const double _cardBorderRadius = onboardingCardBorderRadius;
const double _cardPaddingHorizontal = onboardingCardPaddingHorizontal;
const double _cardPaddingVertical = onboardingCardPaddingVertical;

const double _selectedBorderWidth = onboardingSelectedBorderWidth;
const double _selectedCardOpacity = onboardingSelectedCardOpacity;
const double _spinnerSize = 16;

// ---------------------------------------------------------------------------
// Internal state machine
// ---------------------------------------------------------------------------

/// The UI phase this screen is in.
enum _Phase {
  /// Initial view — two option buttons, no result yet.
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
  bool _usedGps = false;
  GeocodingResult? _resolvedLocation;
  String _errorMessage = '';

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  GeocodingApi? _ownedApi;

  GeocodingApi _geocodingApi(String proxyBaseUrl, String deviceId) {
    if (widget._geocodingApi != null) return widget._geocodingApi!;

    return _ownedApi ??= GeocodingApi(
      proxyBaseUrl: proxyBaseUrl,
      deviceId: deviceId,
    );
  }

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
        _resolvedLocation = result;
        _phase = _Phase.confirm;
        _usedGps = true;
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      // Permission denied — fall through to manual entry.
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
        _resolvedLocation = result;
        _phase = _Phase.confirm;
        _usedGps = false;
      });
    } on GeocodingNotFoundException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.manual;
        _errorMessage = 'Location not found. Try a different search.';
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

    assert(
      _resolvedLocation != null,
      '_onConfirm called outside confirm phase',
    );

    final GeocodingResult loc = _resolvedLocation!;

    try {
      ref.read(locationProvider.notifier).setManual(lat: loc.lat, lon: loc.lon);

      await ref
          .read(settingsProvider.notifier)
          .setManualLocation(loc.displayName);

      await ref.read(settingsProvider.notifier).setUseGps(value: _usedGps);

      if (!mounted) return;

      final Preferences prefs = await ref.read(preferencesProvider.future);
      // Mark onboarding complete only after all data is written; this is the
      // last onboarding step until the notifications screen (issue #15) is
      // added, at which point setFirstLaunchDone() moves there.
      await prefs.setFirstLaunchDone();

      if (!mounted) return;

      ref.invalidate(preferencesProvider);

      // TODO(onboarding): navigate to notifications screen (issue #15).
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
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
      _resolvedLocation = null;
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

    final ValueChanged<String>? onManualSubmitted =
        onManualSearch == null ? null : (_) => onManualSearch();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _screenPaddingHorizontal,
            vertical: _screenPaddingVertical,
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
                  onSubmitted: onManualSubmitted,
                  onSearch: onManualSearch,
                ),

              if (_phase == _Phase.confirm && _resolvedLocation != null)
                _ConfirmCard(
                  displayName: _resolvedLocation!.displayName,
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
    required this.onSubmitted,
    required this.onSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !loading,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'City, State (e.g. New York, NY)',
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(_itemGap),
                child: SizedBox.square(
                  dimension: _spinnerSize,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              )
            : IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
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
    final BorderRadius radius = BorderRadius.circular(_cardBorderRadius);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _cardPaddingHorizontal,
        vertical: _cardPaddingVertical,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.primary, width: _selectedBorderWidth),
        color: colors.primary.withValues(alpha: _selectedCardOpacity),
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
