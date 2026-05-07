import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';

const _defaultTimeout = Duration(seconds: 10);

class UvApi {
  UvApi({
    required Cache cache,
    required String proxyBaseUrl,
    Duration timeout = _defaultTimeout,
    http.Client? httpClient,
  }) : _cache = cache,
       _proxyBaseUrl = proxyBaseUrl,
       _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client();
  final Cache _cache;
  final String _proxyBaseUrl;
  final Duration _timeout;
  final http.Client _httpClient;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  Future<UvData> fetch({
    required double lat,
    required double lon,
    required String uuid,
  }) async {
    if (_cache.isValid) {
      final cached = _cache.read();
      if (cached != null) return cached;
    }

    final uri = Uri.parse(
      '$_proxyBaseUrl/api/uv',
    ).replace(queryParameters: {'lat': lat.toString(), 'lon': lon.toString()});

    // TODO(retry): add exponential backoff for TimeoutException
    //   and transient errors
    final response = await _httpClient
        .get(uri, headers: {'X-Device-ID': uuid})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw UvApiException(response.statusCode, response.body);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw UvApiException(response.statusCode, response.body);
    }

    if (decoded is! Map<String, dynamic>) {
      throw UvApiException(response.statusCode, response.body);
    }
    final data = UvData.fromJson(decoded);

    await _cache.store(data);
    return data;
  }
}

class UvApiException implements Exception {
  UvApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'UvApiException($statusCode): $body';
}
