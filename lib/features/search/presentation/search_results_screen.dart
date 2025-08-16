import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchResultsScreen extends StatefulWidget {
	const SearchResultsScreen({super.key, required this.query});
	final String query;
	@override
	State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
	Future<Map<String, List<Map<String, dynamic>>>> _search(String q) async {
		final db = FirebaseFirestore.instance;
		final like = q.toLowerCase();
		// Simple contains match by fetching limited docs and filtering client-side for demo
		final vendorsSnap = await db.collection('vendors').limit(30).get();
		final providersSnap = await db.collection('providers').limit(30).get();
		final listingsSnap = await db.collection('listings').limit(30).get();
		List<Map<String, dynamic>> vendors = vendorsSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((v) => (v['name'] ?? '').toString().toLowerCase().contains(like) || (v['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		List<Map<String, dynamic>> providers = providersSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((p) => (p['name'] ?? '').toString().toLowerCase().contains(like) || (p['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		List<Map<String, dynamic>> listings = listingsSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((l) => (l['title'] ?? '').toString().toLowerCase().contains(like) || (l['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		return {
			'vendors': vendors,
			'providers': providers,
			'listings': listings,
		};
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: Text('Search: "${widget.query}"')),
			body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
				future: _search(widget.query),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!;
					final sections = [
						('Vendors', data['vendors'] ?? const []),
						('Providers', data['providers'] ?? const []),
						('Marketplace', data['listings'] ?? const []),
					];
					if (sections.every((s) => s.$2.isEmpty)) return const Center(child: Text('No results'));
					return ListView(
						children: [
							for (final section in sections) ...[
								if (section.$2.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(section.$1, style: Theme.of(context).textTheme.titleMedium)),
								for (final item in section.$2)
									ListTile(
										title: Text(item['name'] ?? item['title'] ?? 'Item'),
										subtitle: Text(item['category']?.toString() ?? ''),
										onTap: () {
											if (section.$1 == 'Vendors') {
												final cat = (item['category'] ?? '').toString();
												if (cat.isNotEmpty) context.push('/food/vendors/${cat}');
											} else if (section.$1 == 'Providers') {
												context.push('/profile/provider?providerId=${item['id']}');
											} else {
												context.push('/marketplace');
											}
										},
									),
							],
						],
					);
				},
			),
		);
	}
}