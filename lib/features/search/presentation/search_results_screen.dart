import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SearchResultsScreen extends StatefulWidget {
	const SearchResultsScreen({super.key, required this.query});
	final String query;
	@override
	State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
	final _controller = TextEditingController();
	String _activeSection = 'All';
	int _limit = 20;
	stt.SpeechToText? _speech;

	Future<Map<String, List<Map<String, dynamic>>>> _search(String q) async {
		final db = FirebaseFirestore.instance;
		final like = q.toLowerCase();
		final vendorsSnap = await db.collection('vendors').limit(_limit).get();
		final providersSnap = await db.collection('providers').limit(_limit).get();
		final listingsSnap = await db.collection('listings').limit(_limit).get();
		List<Map<String, dynamic>> vendors = vendorsSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((v) => (v['name'] ?? '').toString().toLowerCase().contains(like) || (v['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		List<Map<String, dynamic>> providers = providersSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((p) => (p['name'] ?? '').toString().toLowerCase().contains(like) || (p['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		List<Map<String, dynamic>> listings = listingsSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((l) => (l['title'] ?? '').toString().toLowerCase().contains(like) || (l['category'] ?? '').toString().toLowerCase().contains(like)).toList();
		return {
			'vendors': vendors,
			'providers': providers,
			'listings': listings,
		};
	}

	Future<void> _voiceSearch() async {
		_speech ??= stt.SpeechToText();
		final ok = await _speech!.initialize(onError: (_) {});
		if (!ok) return;
		_speech!.listen(onResult: (r) {
			_controller.text = r.recognizedWords;
			_controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
			if (r.finalResult) setState(() {});
		});
	}

	@override
	void initState() {
		super.initState();
		_controller.text = widget.query;
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Search')),
			body: Column(
				children: [
					Padding(
						padding: const EdgeInsets.all(8.0),
						child: Row(children: [
							Expanded(
								child: TextField(
									controller: _controller,
									textInputAction: TextInputAction.search,
									onSubmitted: (_) => setState(() {}),
									decoration: InputDecoration(
										filled: true,
										hintText: 'Search...',
										prefixIcon: const Icon(Icons.search),
										border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
									),
								),
							),
							IconButton(onPressed: _voiceSearch, icon: const Icon(Icons.mic_none)),
							const SizedBox(width: 8),
							DropdownButton<String>(
								value: _activeSection,
								items: const [
									DropdownMenuItem(value: 'All', child: Text('All')),
									DropdownMenuItem(value: 'Vendors', child: Text('Vendors')),
									DropdownMenuItem(value: 'Providers', child: Text('Providers')),
									DropdownMenuItem(value: 'Marketplace', child: Text('Marketplace')),
								],
								onChanged: (v) => setState(() => _activeSection = v ?? 'All'),
							),
					]),
					),
					Expanded(
						child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
							future: _search(_controller.text.trim()),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								final data = snap.data!;
								final sections = [
									('Vendors', data['vendors'] ?? const []),
									('Providers', data['providers'] ?? const []),
									('Marketplace', data['listings'] ?? const []),
								];
								final filtered = _activeSection == 'All' ? sections : sections.where((s) => s.$1 == _activeSection).toList();
								if (filtered.every((s) => s.$2.isEmpty)) return const Center(child: Text('No results'));
								return ListView(
									children: [
										for (final section in filtered) ...[
											if (section.$2.isNotEmpty)
												Padding(
													padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
													child: Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
												),
											for (final item in section.$2)
												ListTile(
													title: Text(item['name'] ?? item['title'] ?? 'Item'),
													subtitle: Text(item['category']?.toString() ?? ''),
													onTap: () {
														if (section.$1 == 'Vendors') {
															context.push('/vendor?vendorId=${item['id']}');
														} else if (section.$1 == 'Providers') {
															context.push('/provider?providerId=${item['id']}');
														} else {
															context.push('/listing?productId=${item['id']}');
														}
													},
												),
											if (section.$2.length >= _limit)
												Center(
													child: Padding(
														padding: const EdgeInsets.all(12.0),
														child: OutlinedButton(onPressed: () => setState(() => _limit += 20), child: const Text('Load more')),
													),
												),
										],
									],
								);
							},
						),
					),
				],
			),
		);
	}
}