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
       _uvUri = Uri.parse('${stripTrailingSlash(proxyBaseUrl)}/api/uv'),
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();
  final Cache _cache;
  final Uri _uvUri;
  final Duration _timeout;
  final http.Client _httpClient;
  final bool _ownsClient;

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  /// Returns UV data for the given coordinates, using the cache when valid.
  ///
  /// [appVersion] is sent as the `app_version` query parameter on every
  /// request so the proxy can enforce a minimum supported version -- see
  /// `docs/adr/0009-force-update-via-426.md`. The proxy reads this from the
  /// query string, not a header (confirmed against the deployed proxy;
  /// there is no header fallback, unlike [deviceIdHeader]/`uuid`).
  ///
  /// Throws [UvApiForceUpdateException] on a 426 response.
  /// Throws [UvApiException] on any other non-200 response.
  /// Throws [UvApiParseException] when a 200 response's body is
  /// unparseable -- kept distinct from [UvApiException] since it is not a
  /// non-200 proxy response and must not count toward the
  /// `docs/adr/0010-proxy-error-code-contract.md` consecutive-failure
  /// escalation counter (see `ProxyErrorState` in `uv_provider.dart`).
  /// Throws a timeout exception when the request exceeds the configured
  /// timeout.
  Future<UvData> fetch({
    required double lat,
    required double lon,
    required String uuid,
    required String appVersion,
  }) async {
    if (_cache.isValid) {
      final UvData? cached = await _cache.read();

      if (cached != null) return cached;
    }

    final Uri uri = _uvUri.replace(
      queryParameters: <String, String>{
        'lat': lat.toString(),
        'lon': lon.toString(),
        'app_version': appVersion,
      },
    );

    // TODO(retry): add exponential backoff for TimeoutException
    //   and transient errors
    final http.Response response = await _httpClient
        .get(uri, headers: <String, String>{deviceIdHeader: uuid})
        .timeout(_timeout);

    if (response.statusCode == httpUpgradeRequired) {
      throw const UvApiForceUpdateException();
    }

    if (response.statusCode != httpOk) {
      throw UvApiException(response.statusCode, response.body);
    }

    final UvData data;

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! Map<String, Object?>) {
        throw UvApiParseException(response.body);
      }

      data = UvData.fromJson(decoded);
    } on UvApiParseException {
      rethrow;
    } on Object catch (e) {
      throw UvApiParseException('parse error: $e');
    }

    await _cache.store(data);
    return data;
  }
}

/// Thrown when the proxy returns 426 (app version too old).
///
/// See `docs/adr/0009-force-update-via-426.md`.
class UvApiForceUpdateException implements Exception {
  /// Creates a [UvApiForceUpdateException].
  const UvApiForceUpdateException();
}

/// Thrown when the UV API returns a non-200 status.
class UvApiException implements Exception {
  /// Creates a [UvApiException] with the given [statusCode] and [body].
  UvApiException(this.statusCode, this.body);

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The response body.
  final String body;

  // Override toString for debuggability only - the app works without it.
  // Without this, logs and error messages show "Instance of 'UvApiException'"
  // which is useless. This makes it readable: "UvApiException(404): Not Found".
  @override
  String toString() => 'UvApiException($statusCode): $body';
}

/// Thrown when a 200 response's body is unparseable.
///
/// Kept distinct from [UvApiException] since this is not a non-200 proxy
/// response -- it must not count toward the
/// `docs/adr/0010-proxy-error-code-contract.md` consecutive-failure
/// escalation counter (see `ProxyErrorState` in `uv_provider.dart`).
class UvApiParseException implements Exception {
  /// Creates a [UvApiParseException] with the given [body] or synthesized
  /// error message.
  UvApiParseException(this.body);

  /// The response body, or a synthesized error message.
  final String body;

  @override
  String toString() => 'UvApiParseException: $body';
}
