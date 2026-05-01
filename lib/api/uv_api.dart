import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';

class UvApi {
  final Cache _cache;
  final String _proxyBaseUrl;

  UvApi({required Cache cache, required String proxyBaseUrl})
    : _cache = cache,
      _proxyBaseUrl = proxyBaseUrl;

  Future<UvData> fetch({
    required double lat,
    required double lon,
    required String uuid,
  }) async {
    if (_cache.isValid) {
      return _cache.read()!;
    }

    final uri = Uri.parse('$_proxyBaseUrl/api/uv').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'uuid': uuid,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw UvApiException(response.statusCode, response.body);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw UvApiException(response.statusCode, response.body);
    }

    final data = UvData.fromJson(decoded as Map<String, dynamic>);

    await _cache.store(data);
    return data;
  }
}

class UvApiException implements Exception {
  final int statusCode;
  final String body;

  UvApiException(this.statusCode, this.body);

  @override
  String toString() => 'UvApiException($statusCode): $body';
}
