import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

class ApiClient {
	ApiClient._internal()
		: _logger = Logger(),
			_dio = Dio(
				BaseOptions(
					baseUrl: dotenv.env['API_BASE_URL'] ?? '',
					connectTimeout: const Duration(seconds: 20),
					receiveTimeout: const Duration(seconds: 20),
					headers: {
						'Content-Type': 'application/json',
					},
				),
			);

	static final ApiClient instance = ApiClient._internal();

	final Dio _dio;
	final Logger _logger;

	Dio get client => _dio
		..interceptors.add(
			InterceptorsWrapper(
				onRequest: (options, handler) {
					_logger.d('➡️ ${options.method} ${options.uri}');
					return handler.next(options);
				},
				onResponse: (response, handler) {
					_logger.d('✅ ${response.statusCode} ${response.requestOptions.uri}');
					return handler.next(response);
				},
				onError: (e, handler) {
					_logger.e('❌ ${e.requestOptions.uri} ${e.message}');
					return handler.next(e);
				},
			),
		);
}