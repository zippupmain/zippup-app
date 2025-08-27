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
		return Scaffold(
			appBar: AppBar(
				title: Text('Vendors • ${widget.category.replaceAll('_', ' ')}'),
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
					return Column(children: [
						SizedBox(
							height: 220,
							child: Builder(builder: (context) {
								if (center == null) return const Center(child: Text('Map: no location yet'));
								try {
									if (kIsWeb) {
										final fmMarkers = markers.map<lm.Marker>((m) => lm.Marker(
											point: ll.LatLng(m.position.latitude, m.position.longitude),
											width: 40,
											height: 40,
											child: const Icon(Icons.location_on, color: Colors.redAccent),
										)).toList();
										return lm.FlutterMap(
											options: lm.MapOptions(initialCenter: ll.LatLng(center!.latitude, center!.longitude), initialZoom: 12),
											children: [
												lm.TileLayer(
													urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
													userAgentPackageName: 'com.zippup.app',
													maxZoom: 19,
												),
												lm.MarkerLayer(markers: fmMarkers),
											],
										);
									}
									return GoogleMap(initialCameraPosition: CameraPosition(target: center!, zoom: 12), markers: markers, myLocationEnabled: false, compassEnabled: false);
								} catch (_) {
									return const Center(child: Text('Map failed to load'));
								}
							}),
						),
						const Divider(height: 1),
						Expanded(
							child: ListView.separated(
								itemCount: docs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final v = docs[i].data();
									final vid = docs[i].id;
									final dist = _dist(v);
									return ListTile(
										title: Text(v['name'] ?? 'Vendor'),
										subtitle: Text([ (v['rating'] ?? 0).toString(), if (dist.isNotEmpty) dist ].join(' • ')),
										trailing: Wrap(spacing: 8, children: [
											IconButton(onPressed: () => context.pushNamed('chat', pathParameters: {'threadId': 'vendor_$vid'}, queryParameters: {'title': v['name'] ?? 'Chat'}), icon: const Icon(Icons.chat_bubble_outline)),
											TextButton(onPressed: () => context.push('/vendor?vendorId=$vid'), child: const Text('View')),
										]),
									);
								},
							),
						),
					]);
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