import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uvalert/constants.dart';

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
    Duration timeout = apiDefaultTimeout,
    http.Client? httpClient,
  }) : _geocodeUri = Uri.parse(
         '${stripTrailingSlash(proxyBaseUrl)}/api/geocode',
       ),
       _deviceId = deviceId,
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();

  final Duration _timeout;
  final String _deviceId;
  final http.Client _httpClient;
  final bool _ownsClient;
  final Uri _geocodeUri;

  late final Map<String, String> _headers = <String, String>{
    deviceIdHeader: _deviceId,
  };

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  /// Resolves a location [query] string (e.g. "Fresno") to a list of
  /// candidate matches, ordered by relevance.
  ///
  /// Returns between 1 and 5 results. Throws [GeocodingNotFoundException]
  /// when the proxy returns 404 (no match) or the response contains no
  /// usable results. Throws [GeocodingException] on any other non-200
  /// response or parse error.
  Future<List<GeocodingResult>> geocodeMultiple(String query) async {
    final Uri uri = _geocodeUri.replace(
      queryParameters: <String, String>{'q': query},
    );

    final http.Response response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(_timeout);

    return _parseResults(response);
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

    return _parseResult(response);
  }

  List<GeocodingResult> _parseResults(http.Response response) {
    _checkStatus(response);

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! List<Object?>) {
        throw GeocodingException(response.statusCode, response.body);
      }

      final List<GeocodingResult> results = <GeocodingResult>[];

      for (final Object? item in decoded) {
        if (item is! Map<String, Object?>) continue;

        final GeocodingResult? result = _itemToResult(item);
        if (result != null) results.add(result);
      }

      if (results.isEmpty) {
        throw const GeocodingNotFoundException();
      }

      return results;
    } on FormatException catch (e) {
      throw GeocodingException(response.statusCode, 'parse error: $e');
    }
  }

  GeocodingResult _parseResult(http.Response response) {
    _checkStatus(response);

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! Map<String, Object?>) {
        throw GeocodingException(response.statusCode, response.body);
      }

      final GeocodingResult? result = _itemToResult(decoded);
      if (result == null) {
        throw GeocodingException(response.statusCode, response.body);
      }

      return result;
    } on FormatException catch (e) {
      throw GeocodingException(response.statusCode, 'parse error: $e');
    }
  }

  static void _checkStatus(http.Response response) {
    if (response.statusCode == httpNotFound) {
      throw const GeocodingNotFoundException();
    }
    if (response.statusCode != httpOk) {
      throw GeocodingException(response.statusCode, response.body);
    }
  }

  /// Parses one JSON object into a [GeocodingResult], or returns `null` if
  /// required fields are missing or have the wrong type.
  static GeocodingResult? _itemToResult(Map<String, Object?> item) {
    final Object? lat = item['lat'];
    final Object? lon = item['lon'];
    final Object? name = item['name'];
    final Object? country = item['country'];
    final Object? state = item['state'];

    if (lat is! num || lon is! num || name is! String || country is! String) {
      return null;
    }

    final String displayName = state is String
        ? '$name, $state, $country'
        : '$name, $country';

    return (lat: lat.toDouble(), lon: lon.toDouble(), displayName: displayName);
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
