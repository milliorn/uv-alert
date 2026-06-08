import 'dart:convert';

import 'package:http/http.dart' as http;

const Duration _defaultTimeout = Duration(seconds: 10);
const int _httpOk = 200;
const int _httpNotFound = 404;

/// Result from a geocoding or reverse-geocoding call.
typedef GeocodingResult = ({double lat, double lon, String displayName});

/// HTTP client for geocoding and reverse-geocoding via the proxy.
///
/// Forward geocoding: city string -> coords + display name.
/// Reverse geocoding: coords -> display name.
class GeocodingApi {
  /// Creates a [GeocodingApi].
  ///
  /// If [httpClient] is omitted an internal client is created and owned by
  /// this instance (closed on [dispose]).
  GeocodingApi({
    required String proxyBaseUrl,
    Duration timeout = _defaultTimeout,
    http.Client? httpClient,
  }) : _proxyBaseUrl = proxyBaseUrl.endsWith('/')
           ? proxyBaseUrl.substring(0, proxyBaseUrl.length - 1)
           : proxyBaseUrl,
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();

  final Duration _timeout;
  final http.Client _httpClient;
  final bool _ownsClient;
  late final Uri _geoUri = Uri.parse('$_proxyBaseUrl/api/geo');
  final String _proxyBaseUrl;

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  /// Resolves a location [query] string (e.g. "Fresno, CA") to coordinates
  /// and a human-readable display name.
  ///
  /// Throws [GeocodingNotFoundException] when the proxy returns 404 (no match).
  /// Throws [GeocodingException] on any other non-200 response or parse error.
  Future<GeocodingResult> geocode(String query) async {
    final Uri uri = _geoUri.replace(
      queryParameters: <String, String>{'q': query},
    );

    final http.Response response = await _httpClient.get(uri).timeout(_timeout);

    if (response.statusCode == _httpNotFound) {
      throw const GeocodingNotFoundException();
    }

    return _parseResult(response);
  }

  /// Resolves [lat]/[lon] to a human-readable display name.
  ///
  /// Returns a [GeocodingResult] with the same [lat]/[lon] passed in plus
  /// the resolved display name from the proxy.
  ///
  /// Throws [GeocodingNotFoundException] when the proxy returns 404.
  /// Throws [GeocodingException] on any other non-200 response or parse error.
  Future<GeocodingResult> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    final Uri uri = _geoUri.replace(
      queryParameters: <String, String>{
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );

    final http.Response response = await _httpClient.get(uri).timeout(_timeout);

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
      final Object? displayName = decoded['display_name'];

      if (lat is! num || lon is! num || displayName is! String) {
        throw GeocodingException(response.statusCode, response.body);
      }

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
