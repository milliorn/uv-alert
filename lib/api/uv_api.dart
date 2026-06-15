import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';

/// HTTP client for fetching UV data from the proxy API.
class UvApi {
  /// Creates a [UvApi] instance.
  ///
  /// If [httpClient] is omitted, an internal client is created and owned by
  /// this instance (closed on [dispose]). Pass your own client to share or
  /// mock it; [dispose] will not close it in that case.
  UvApi({
    required Cache cache,
    required String proxyBaseUrl,
    Duration timeout = apiDefaultTimeout,
    http.Client? httpClient,
  }) : _cache = cache,
       _proxyBaseUrl = stripTrailingSlash(proxyBaseUrl),
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();
  final Cache _cache;
  final String _proxyBaseUrl;
  final Duration _timeout;
  final http.Client _httpClient;
  final bool _ownsClient;

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  /// Returns UV data for the given coordinates, using the cache when valid.
  ///
  /// Throws [UvApiException] on a non-200 response or unparseable body.
  /// Throws a timeout exception when the request exceeds the configured
  /// timeout.
  Future<UvData> fetch({
    required double lat,
    required double lon,
    required String uuid,
  }) async {
    if (_cache.isValid) {
      final UvData? cached = await _cache.read();

      if (cached != null) return cached;
    }

    final Uri uri = Uri.parse('$_proxyBaseUrl/api/uv').replace(
      queryParameters: <String, String>{
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );

    // TODO(retry): add exponential backoff for TimeoutException
    //   and transient errors
    final http.Response response = await _httpClient
        .get(uri, headers: <String, String>{deviceIdHeader: uuid})
        .timeout(_timeout);

    if (response.statusCode != httpOk) {
      throw UvApiException(response.statusCode, response.body);
    }

    final UvData data;

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! Map<String, Object?>) {
        throw UvApiException(response.statusCode, response.body);
      }

      data = UvData.fromJson(decoded);
    } on UvApiException {
      rethrow;
    } on Object catch (e) {
      throw UvApiException(response.statusCode, 'parse error: $e');
    }

    await _cache.store(data);
    return data;
  }
}

/// Thrown when the UV API returns a non-200 status or an unparseable body.
class UvApiException implements Exception {
  /// Creates a [UvApiException] with the given [statusCode] and [body].
  UvApiException(this.statusCode, this.body);

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The response body, or a synthesized error message on parse failure.
  final String body;

  // Override toString for debuggability only - the app works without it.
  // Without this, logs and error messages show "Instance of 'UvApiException'"
  // which is useless. This makes it readable: "UvApiException(404): Not Found".
  @override
  String toString() => 'UvApiException($statusCode): $body';
}
