import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uvalert/constants.dart';

const Duration _defaultTimeout = Duration(seconds: 10);
const int _httpOk = 200;
const int _httpNotFound = 404;

/// Result from a geocoding call.
typedef GeocodingResult = ({double lat, double lon, String displayName});

/// HTTP client for forward and reverse geocoding via the proxy.
///
/// Forward geocoding: city string -> coords + display name (`geocode`).
/// Reverse geocoding: lat/lon -> display name (`reverseGeocode`).
///
/// Both methods use `GET /api/geocode` with the device UUID sent as the
/// `X-Device-ID` request header.
///
/// Response shape: `{ lat, lon, name, country, state? }`.
class GeocodingApi {
  /// Creates a [GeocodingApi].
  ///
  /// If [httpClient] is omitted an internal client is created and owned by
  /// this instance (closed on [dispose]).
  GeocodingApi({
    required String proxyBaseUrl,
    required String deviceId,
    Duration timeout = _defaultTimeout,
    http.Client? httpClient,
  }) : _proxyBaseUrl = proxyBaseUrl.endsWith('/')
           ? proxyBaseUrl.substring(0, proxyBaseUrl.length - 1)
           : proxyBaseUrl,
       _deviceId = deviceId,
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();

  final Duration _timeout;
  final String _deviceId;
  final http.Client _httpClient;
  final bool _ownsClient;
  late final Uri _geocodeUri = Uri.parse('$_proxyBaseUrl/api/geocode');
  late final Map<String, String> _headers = <String, String>{
    deviceIdHeader: _deviceId,
  };
  final String _proxyBaseUrl;

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  /// Resolves a location [query] string (e.g. "Fresno") to coordinates
  /// and a human-readable display name.
  ///
  /// Throws [GeocodingNotFoundException] when the proxy returns 404 (no match).
  /// Throws [GeocodingException] on any other non-200 response or parse error.
  Future<GeocodingResult> geocode(String query) async {
    final Uri uri = _geocodeUri.replace(
      queryParameters: <String, String>{'q': query},
    );

    final http.Response response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == _httpNotFound) {
      throw const GeocodingNotFoundException();
    }

    return _parseResult(response);
  }

  /// Resolves GPS [lat]/[lon] coordinates to a human-readable display name.
  ///
  /// Throws [GeocodingNotFoundException] when the proxy returns 404 (no match).
  /// Throws [GeocodingException] on any other non-200 response or parse error.
  Future<GeocodingResult> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    final Uri uri = _geocodeUri.replace(
      queryParameters: <String, String>{
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );

    final http.Response response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == _httpNotFound) {
      throw const GeocodingNotFoundException();
    }

    return _parseResult(response);
  }

  GeocodingResult _parseResult(http.Response response) {
    if (response.statusCode != _httpOk) {
      throw GeocodingException(response.statusCode, response.body);
    }

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! Map<String, Object?>) {
        throw GeocodingException(response.statusCode, response.body);
      }

      final Object? lat = decoded['lat'];
      final Object? lon = decoded['lon'];
      final Object? name = decoded['name'];
      final Object? country = decoded['country'];
      final Object? state = decoded['state'];

      if (lat is! num || lon is! num || name is! String || country is! String) {
        throw GeocodingException(response.statusCode, response.body);
      }

      final String displayName = state is String
          ? '$name, $state, $country'
          : '$name, $country';

      return (
        lat: lat.toDouble(),
        lon: lon.toDouble(),
        displayName: displayName,
      );
    } on FormatException catch (e) {
      throw GeocodingException(response.statusCode, 'parse error: $e');
    }
  }
}

/// Thrown when the proxy returns 404 (location not found).
class GeocodingNotFoundException implements Exception {
  /// Creates a [GeocodingNotFoundException].
  const GeocodingNotFoundException();
}

/// Thrown when the geocoding API returns a non-200/404 status or unparseable body.
class GeocodingException implements Exception {
  /// Creates a [GeocodingException] with the given [statusCode] and [body].
  GeocodingException(this.statusCode, this.body);

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The response body, or a synthesized error message on parse failure.
  final String body;

  @override
  String toString() => 'GeocodingException($statusCode): $body';
}
