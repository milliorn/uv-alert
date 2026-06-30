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
import 'package:uvalert/storage/preferences.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const int _locationScreenIndex = 1;

const double _spinnerSize = 16;
const double _spinnerStrokeWidth = 2;
const int _debounceMs = 400;
const int _minQueryLength = 2;
const double _appBarElevation = 0;

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

  /// Multiple geocoding results returned; user must pick one.
  picking,
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
  List<GeocodingResult> _candidates = <GeocodingResult>[];
  List<GeocodingResult> _suggestions = <GeocodingResult>[];
  String _errorMessage = '';
  Timer? _debounce;
  // Incremented whenever the user navigates away (back, search-again, change).
  // Async callbacks capture this value before their await and discard their
  // result if the counter has advanced, preventing stale state overwrites.
  int _operationId = 0;

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
    _debounce?.cancel();
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

      // Inner try/catch isolates the HTTP timeout from the GPS timeout above.
      // Both throw TimeoutException but require different error messages.
      GeocodingResult result;

      try {
        result = await _geocodingApi(
          proxyBaseUrl,
          deviceId,
        ).reverseGeocode(lat: loc.lat, lon: loc.lon);
      } on TimeoutException {
        if (!mounted) return;
        _setError('Could not determine your city. Try entering it manually.');
        return;
      }

      if (!mounted) return;

      _setConfirmed(result, fromGps: true);
    } on PermissionDeniedException {
      if (!mounted) return;
      // Permission denied; fall through to manual entry.
      setState(() => _phase = _Phase.manual);
      _manualFocus.requestFocus();
    } on TimeoutException {
      if (!mounted) return;
      _setError(
        'GPS is not available on this device. '
        'Try entering your location manually.',
      );
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

  void _onChanged(String value, String proxyBaseUrl, String deviceId) {
    _debounce?.cancel();
    _operationId++;

    setState(() {
      _suggestions = <GeocodingResult>[];
      _errorMessage = '';
    });

    if (value.trim().length < _minQueryLength) return;

    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _onDebounced(value.trim(), proxyBaseUrl, deviceId),
    );
  }

  Future<void> _onDebounced(
    String query,
    String proxyBaseUrl,
    String deviceId,
  ) async {
    final int opId = _operationId;

    try {
      final List<GeocodingResult> results = await _geocodingApi(
        proxyBaseUrl,
        deviceId,
      ).autocomplete(query);

      if (!mounted || _operationId != opId) return;

      setState(() => _suggestions = results);
    } on GeocodingNotFoundException {
      if (!mounted || _operationId != opId) return;

      setState(() => _suggestions = <GeocodingResult>[]);
    } on Object catch (e, st) {
      debugPrint('Autocomplete error: $e\n$st');

      if (!mounted || _operationId != opId) return;

      setState(() => _suggestions = <GeocodingResult>[]);
    }
  }

  Future<void> _onGeocodeManual(String proxyBaseUrl, String deviceId) async {
    _debounce?.cancel();

    final String query = _manualController.text.trim();

    if (query.isEmpty) return;

    final int opId = ++_operationId;

    setState(() {
      _phase = _Phase.geocoding;
      _errorMessage = '';
    });

    try {
      final List<GeocodingResult> results = await _geocodingApi(
        proxyBaseUrl,
        deviceId,
      ).geocodeMultiple(query);

      if (!mounted || _operationId != opId) return;

      if (results.length == 1) {
        _setConfirmed(results.first, fromGps: false);
      } else {
        setState(() {
          _candidates = results;
          _phase = _Phase.picking;
        });
      }
    } on GeocodingNotFoundException {
      if (!mounted || _operationId != opId) return;

      setState(() {
        _phase = _Phase.manual;
        _suggestions = <GeocodingResult>[];
        _errorMessage =
            'Location not found. Try adding region and country'
            ' (e.g. "Washington, DC, US" or "London, England, GB").';
      });
    } on Object catch (e, st) {
      debugPrint('Manual geocoding error: $e\n$st');

      if (!mounted || _operationId != opId) return;

      setState(() {
        _phase = _Phase.manual;
        _suggestions = <GeocodingResult>[];
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _onPick(GeocodingResult result) {
    _debounce?.cancel();

    _setConfirmed(result, fromGps: false);
  }

  void _setConfirmed(GeocodingResult result, {required bool fromGps}) {
    setState(() {
      _candidates = <GeocodingResult>[];
      _suggestions = <GeocodingResult>[];
      _pending = (result: result, fromGps: fromGps);
      _phase = _Phase.confirm;
    });
  }

  void _onSearchAgain() {
    _debounce?.cancel();
    _operationId++;
    setState(() {
      _candidates = <GeocodingResult>[];
      _suggestions = <GeocodingResult>[];
      _phase = _Phase.manual;
      _errorMessage = '';
      _continuing = false;
    });
    _manualFocus.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Confirm / continue
  // -------------------------------------------------------------------------

  Future<void> _onConfirm() async {
    setState(() => _continuing = true);

    assert(_pending != null, '_onConfirm called outside confirm phase');

    final int opId = ++_operationId;
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

      final Preferences prefs = await ref.read(preferencesProvider.future);

      await prefs.setLocationStepDone();

      if (!mounted || _operationId != opId) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationOnboardingScreen(),
          ),
        ),
      );
    } on Object catch (e, st) {
      debugPrint('Confirm error: $e\n$st');

      if (!mounted || _operationId != opId) return;

      setState(() {
        _continuing = false;
        _phase = _Phase.confirm;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _onChangeLocation() {
    _debounce?.cancel();
    _operationId++;

    setState(() {
      _phase = _Phase.manual;
      _pending = null;
      _suggestions = <GeocodingResult>[];
      _errorMessage = '';
      _continuing = false;
    });

    _manualFocus.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _onBack() {
    _debounce?.cancel();
    _operationId++;
    _manualController.clear();

    setState(() {
      _phase = _Phase.idle;
      _candidates = <GeocodingResult>[];
      _suggestions = <GeocodingResult>[];
      _errorMessage = '';
      _pending = null;
      _continuing = false;
    });
  }

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

    final ValueChanged<String>? onChanged = deviceId == null
        ? null
        : (String v) => _onChanged(v, proxyBaseUrl, deviceId);

    final bool canGoBack = _phase != _Phase.idle && _phase != _Phase.loading;

    return Scaffold(
      appBar: canGoBack
          ? AppBar(
              leading: BackButton(onPressed: _onBack),
              backgroundColor: Colors.transparent,
              elevation: _appBarElevation,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingPaddingHorizontal,
            vertical: onboardingPaddingVertical,
          ),
          child: Column(
            spacing: onboardingSectionGap,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    spacing: onboardingSectionGap,
                    children: <Widget>[
                      const SizedBox(height: onboardingSectionGap),

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
                          onChanged: onChanged,
                        ),

                      if (_phase == _Phase.manual && _suggestions.isNotEmpty)
                        _SuggestionList(
                          suggestions: _suggestions,
                          onPick: _onPick,
                        ),

                      if (_phase == _Phase.picking)
                        _PickList(
                          candidates: _candidates,
                          onPick: _onPick,
                          onSearchAgain: _onSearchAgain,
                        ),

                      if (_phase == _Phase.confirm)
                        _ConfirmCard(
                          displayName: _pending!.result.displayName,
                          onChange: _onChangeLocation,
                        ),

                      if (_errorMessage.isNotEmpty)
                        _ErrorText(message: _errorMessage),

                      const SizedBox(height: onboardingSectionGap),
                    ],
                  ),
                ),
              ),

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
    final ThemeData theme = Theme.of(context);
    return Column(
      spacing: onboardingItemGap,
      children: <Widget>[
        Text('Your Location', style: theme.textTheme.headlineMedium),
        Text(
          'UV Alert uses your location to provide accurate UV readings '
          'for your area.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
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
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  // No onSubmitted parameter: TextField.onSubmitted passes the field value
  // which this widget never uses. The adapter (_) => onSearch!() is derived
  // here from onSearch so the caller stays free of that boilerplate.
  final VoidCallback? onSearch;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !loading,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSearch == null ? null : (_) => onSearch!(),
      decoration: InputDecoration(
        hintText: 'City, Region, Country (e.g. Washington, DC, US)',
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(onboardingItemGap),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: onboardingCardPaddingHorizontal,
        vertical: onboardingCardPaddingVertical,
      ),
      decoration: BoxDecoration(
        borderRadius: onboardingCardRadius,
        border: Border.all(
          color: colors.primary,
          width: onboardingSelectedBorderWidth,
        ),
        color: colors.primary.withValues(alpha: onboardingSelectedCardOpacity),
      ),
      child: Column(
        spacing: onboardingItemGap,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on, color: colors.primary),
              const SizedBox(width: onboardingItemGap),
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Location is approximate and may vary based on device GPS '
            'accuracy, network conditions, or other factors.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
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

class _PickList extends StatelessWidget {
  const _PickList({
    required this.candidates,
    required this.onPick,
    required this.onSearchAgain,
  });

  final List<GeocodingResult> candidates;
  final void Function(GeocodingResult) onPick;
  final VoidCallback onSearchAgain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      spacing: onboardingItemGap,
      children: <Widget>[
        Text('Select your location:', style: theme.textTheme.bodyMedium),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height *
                onboardingPickListMaxHeightFraction,
          ),
          child: ListView.separated(
            itemCount: candidates.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: onboardingItemGap),
            itemBuilder: (_, int i) => SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onPick(candidates[i]),
                child: Text(
                  candidates[i].displayName,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Text(
          'Not your city? Try adding region and country'
          ' (e.g. "Washington, DC, US" or "London, England, GB").',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        TextButton(onPressed: onSearchAgain, child: const Text('Search again')),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onPick});

  final List<GeocodingResult> suggestions;
  final ValueChanged<GeocodingResult> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: onboardingItemGap),
      itemBuilder: (_, int i) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => onPick(suggestions[i]),
          child: Text(suggestions[i].displayName, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
      textAlign: TextAlign.center,
    );
  }
}
