import 'package:flutter/material.dart';
import 'package:zippup/features/marketplace/models/product.dart';
import 'package:zippup/services/api/marketplace_api.dart';

class MarketplaceScreen extends StatefulWidget {
	const MarketplaceScreen({super.key});

	@override
	State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
	final MarketplaceApi _api = MarketplaceApi();
	List<Product> _products = const [];
	bool _loading = true;
	String? _error;

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() {
			_loading = true;
			_error = null;
		});
		try {
			final items = await _api.fetchProducts();
			setState(() {
				_products = items;
			});
		} catch (e) {
			setState(() {
				_error = 'Failed to load products. Showing offline cache if available.';
				_products = _products; // keep existing in-memory cache
			});
		} finally {
			setState(() {
				_loading = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Marketplace')),
			body: RefreshIndicator(
				onRefresh: _load,
				child: _loading
						? const Center(child: CircularProgressIndicator())
						: _products.isEmpty
								? ListView(children: const [SizedBox(height: 120), Center(child: Text('No products'))])
								: ListView.separated(
									itemCount: _products.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final p = _products[i];
										return ListTile(
											title: Text(p.title),
											subtitle: Text('${p.category} • ${p.price.toStringAsFixed(2)}'),
										);
									},
								),
			),
		);
	}
}