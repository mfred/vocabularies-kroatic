import 'package:dio/dio.dart';

import '../config.dart';

Dio buildDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.dataBaseUrl,
      connectTimeout: AppConfig.httpTimeout,
      receiveTimeout: AppConfig.httpTimeout,
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'vocabularies_kroatic/1.0',
      },
    ),
  );
}
