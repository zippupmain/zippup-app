import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:zippup/services/location/location_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VendorListScreen extends StatefulWidget {
	const VendorListScreen({super.key, required this.category});
	final String category;
	@override
	State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
	final _search = TextEditingController();
	String _q = '';
	geo.Position? _me;
	stt.SpeechToText? _speech;

	@override
	void initState() {
		super.initState();
		_fetchLoc();
	}

	Future<void> _fetchLoc() async {
		final p = await LocationService.getCurrentPosition();
		if (!mounted) return;
		setState(() => _me = p);
	}

	String _dist(Map<String, dynamic> v) {
		final lat = (v['lat'] as num?)?.toDouble();
		final lng = (v['lng'] as num?)?.toDouble();
		if (_me == null || lat == null || lng == null) return '';
		final meters = geo.Geolocator.distanceBetween(_me!.latitude, _me!.longitude, lat, lng);
		final km = meters / 1000.0;
		return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
	}

	Future<void> _mic() async {
		_speech ??= stt.SpeechToText();
		final ok = await _speech!.initialize(onError: (_) {});
		if (!ok) return;
		_speech!.listen(onResult: (r) {
			_search.text = r.recognizedWords;
			_search.selection = TextSelection.fromPosition(TextPosition(offset: _search.text.length));
			if (r.finalResult && mounted) setState(() => _q = _search.text.trim().toLowerCase());
		});
	}

	@override
	Widget build(BuildContext context) {
		final categoryEmojis = {
			'grocery': '🥬',
			'fast_food': '🍔',
			'local': '🍲',
			'pizza': '🍕',
			'chinese': '🥡',
			'desserts': '🍰',
			'drinks': '🥤',
		};
		
		final categoryGradients = {
			'grocery': const LinearGradient(colors: [Color(0xFF8BC34A), Color(0xFFAED581)]),
			'fast_food': const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
			'local': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
			'pizza': const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
			'chinese': const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]),
			'desserts': const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
			'drinks': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
		};
		
		final emoji = categoryEmojis[widget.category] ?? '🍽️';
		final gradient = categoryGradients[widget.category] ?? const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]);
		
		return Scaffold(
			appBar: AppBar(
				title: Text(
					'$emoji ${widget.category.replaceAll('_', ' ').toUpperCase()} Vendors',
					style: const TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 18,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: BoxDecoration(gradient: gradient),
				),
				foregroundColor: Colors.white,
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: _search,
							textInputAction: TextInputAction.search,
							onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
							decoration: InputDecoration(
								filled: true,
								hintText: 'Search vendors...',
								prefixIcon: const Icon(Icons.search),
								suffixIcon: IconButton(icon: const Icon(Icons.mic_none), onPressed: _mic),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
							),
						),
					),
				),
			),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('vendors').where('category', isEqualTo: widget.category).snapshots(),
				builder: (context, snapshot) {
					if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
					if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snapshot.data!.docs.where((d) {
						if (_q.isEmpty) return true;
						final name = (d.data()['name'] ?? '').toString().toLowerCase();
						return name.contains(_q);
					}).toList();

					final markers = <Marker>{};
					LatLng? center;
					if (_me != null) center = LatLng(_me!.latitude, _me!.longitude);
					for (final d in docs) {
						final v = d.data();
						final lat = (v['lat'] as num?)?.toDouble();
						final lng = (v['lng'] as num?)?.toDouble();
						if (lat != null && lng != null) {
							final dist = _dist(v);
							markers.add(Marker(markerId: MarkerId(d.id), position: LatLng(lat, lng), infoWindow: InfoWindow(title: v['name']?.toString() ?? 'Vendor', snippet: dist)));
							center ??= LatLng(lat, lng);
						}
					}
					if (docs.isEmpty) {
						return Center(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Text(emoji, style: const TextStyle(fontSize: 64)),
									const SizedBox(height: 16),
									Text('No ${widget.category.replaceAll('_', ' ')} vendors found', 
										style: const TextStyle(fontSize: 18, color: Colors.grey)),
									const Text('Try adjusting your search', style: TextStyle(color: Colors.grey)),
								],
							),
						);
					}

					return Container(
						decoration: BoxDecoration(
							gradient: LinearGradient(
								begin: Alignment.topCenter,
								end: Alignment.bottomCenter,
								colors: [
									gradient.colors.first.withOpacity(0.1),
									gradient.colors.last.withOpacity(0.05),
								],
							),
						),
						child: ListView.builder(
							padding: const EdgeInsets.all(16),
							itemCount: docs.length,
							itemBuilder: (context, i) {
								final v = docs[i].data();
								final vid = docs[i].id;
								final dist = _dist(v);
								final rating = (v['rating'] as num?)?.toDouble() ?? 0.0;
								final isOpen = v['isOpen'] ?? true;
								final deliveryTime = v['deliveryTime'] ?? '30-45 min';
								
								return Container(
									margin: const EdgeInsets.only(bottom: 16),
									decoration: BoxDecoration(
										gradient: const LinearGradient(
											colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
										),
										borderRadius: BorderRadius.circular(16),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withOpacity(0.1),
												blurRadius: 8,
												offset: const Offset(0, 4),
											),
										],
									),
									child: InkWell(
										onTap: () => context.push('/food/vendor?vendorId=$vid'),
										borderRadius: BorderRadius.circular(16),
										child: Padding(
											padding: const EdgeInsets.all(16),
											child: Row(
												children: [
													// Vendor image/emoji
													Container(
														width: 80,
														height: 80,
														decoration: BoxDecoration(
															gradient: gradient,
															borderRadius: BorderRadius.circular(12),
														),
														child: Center(
															child: Text(
																emoji,
																style: const TextStyle(fontSize: 32),
															),
														),
													),
													const SizedBox(width: 16),
													
													// Vendor details
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(
																	v['name'] ?? 'Vendor',
																	style: const TextStyle(
																		fontWeight: FontWeight.bold,
																		fontSize: 16,
																	),
																),
																const SizedBox(height: 6),
																
																// Status and rating row
																Row(
																	children: [
																		Container(
																			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
																			decoration: BoxDecoration(
																				color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
																				borderRadius: BorderRadius.circular(12),
																			),
																			child: Text(
																				isOpen ? 'OPEN' : 'CLOSED',
																				style: TextStyle(
																					color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
																					fontWeight: FontWeight.bold,
																					fontSize: 10,
																				),
																			),
																		),
																		const SizedBox(width: 8),
																		Row(
																			children: List.generate(5, (index) {
																				return Icon(
																					index < rating ? Icons.star : Icons.star_border,
																					color: Colors.amber,
																					size: 14,
																				);
																			}),
																		),
																		const SizedBox(width: 4),
																		Text('(${rating.toStringAsFixed(1)})', style: const TextStyle(fontSize: 12)),
																	],
																),
																const SizedBox(height: 4),
																
																// Delivery info
																Row(
																	children: [
																		Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
																		const SizedBox(width: 4),
																		Text(deliveryTime, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
																		if (dist.isNotEmpty) ...[
																			const SizedBox(width: 8),
																			Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
																			const SizedBox(width: 4),
																			Text(dist, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
																		],
																	],
																),
															],
														),
													),
													
													// Action buttons
													Column(
														children: [
															Container(
																padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
																decoration: BoxDecoration(
																	gradient: gradient,
																	borderRadius: BorderRadius.circular(20),
																),
																child: const Text(
																	'VIEW MENU',
																	style: TextStyle(
																		color: Colors.white,
																		fontWeight: FontWeight.bold,
																		fontSize: 11,
																	),
																),
															),
															const SizedBox(height: 8),
															InkWell(
																onTap: () => context.pushNamed('chat', 
																	pathParameters: {'threadId': 'vendor_$vid'}, 
																	queryParameters: {'title': v['name'] ?? 'Chat'}),
																child: Container(
																	padding: const EdgeInsets.all(8),
																	decoration: BoxDecoration(
																		color: Colors.grey.shade100,
																		shape: BoxShape.circle,
																	),
																	child: const Icon(Icons.chat_bubble_outline, size: 16),
																),
															),
														],
													),
												],
											),
										),
									),
								);
							},
						),
					);
				},
			),
			bottomNavigationBar: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(12.0),
					child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Checkout')),
				),
			),
		);
	}
}