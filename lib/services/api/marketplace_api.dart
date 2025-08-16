import 'package:dio/dio.dart';
import 'package:zippup/services/api/api_client.dart';
import 'package:zippup/features/marketplace/models/product.dart';

class MarketplaceApi {
	final Dio _dio = ApiClient.instance.client;

	Future<List<Product>> fetchProducts() async {
		final res = await _dio.get('/api/marketplace/products');
		final data = res.data as List<dynamic>;
		return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
	}

	Future<Product> createProduct(Product product) async {
		final res = await _dio.post('/api/marketplace/products', data: product.toJson());
		return Product.fromJson(res.data as Map<String, dynamic>);
	}
}