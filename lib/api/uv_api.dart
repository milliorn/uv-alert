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

  Future<UvData> fetch({required double lat, required double lon, required String uuid}) async {
    if (!_cache.isEmpty() && !_cache.isStale()) {
      return _cache.read()!;
    }

    final uri = Uri.parse('$_proxyBaseUrl/api/uv').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'uuid': uuid,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw HttpException(response.statusCode, response.body);
    }

    final data = UvData.fromJson(jsonDecode(response.body));
    
    await _cache.store(data);
    return data;
  }
}

class HttpException implements Exception {
  final int statusCode;
  final String body;

  HttpException(this.statusCode, this.body);

  @override
  String toString() => 'HttpException($statusCode): $body';
}
