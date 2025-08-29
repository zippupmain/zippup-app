import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/profile/presentation/provider_profile_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:zippup/services/location/location_service.dart';

class EmergencyProvidersScreen extends StatefulWidget {
	const EmergencyProvidersScreen({super.key, required this.type});
	final String type; // ambulance | fire | security | towing
	@override
	State<EmergencyProvidersScreen> createState() => _EmergencyProvidersScreenState();
}

class _EmergencyProvidersScreenState extends State<EmergencyProvidersScreen> {
	final _qController = TextEditingController();
	String _q = '';
	geo.Position? _me;
	String get _title => switch (widget.type) {
		'ambulance' => 'Ambulance',
		'fire' => 'Fire Service',
		'security' => 'Security',
		'towing' => 'Towing',
		_ => 'Emergency'
	};

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

	String _distanceText(Map<String, dynamic> p) {
		final lat = (p['lat'] as num?)?.toDouble();
		final lng = (p['lng'] as num?)?.toDouble();
		if (_me == null || lat == null || lng == null) return '';
		final meters = geo.Geolocator.distanceBetween(_me!.latitude, _me!.longitude, lat, lng);
		final km = meters / 1000.0;
		return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(_title),
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: _qController,
							decoration: const InputDecoration(
								labelText: 'Search providers',
								prefixIcon: Icon(Icons.search),
								border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
								filled: true,
							),
							onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
						),
					),
				),
			),
			body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
				future: FirebaseFirestore.instance.collection('providers').where('category', isEqualTo: widget.type).get(const GetOptions(source: Source.server)),
				builder: (context, snap) {
					if (snap.hasError) return const Center(child: Text('No providers found'));
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs.where((d) {
						if (_q.isEmpty) return true;
						final name = (d.data()['name'] ?? '').toString().toLowerCase();
						final title = (d.data()['title'] ?? '').toString().toLowerCase();
						return name.contains(_q) || title.contains(_q);
					}).toList();
					// Map markers
					final markers = <Marker>{};
					LatLng? center;
					if (_me != null) center = LatLng(_me!.latitude, _me!.longitude);
					for (final d in docs) {
						final p = d.data();
						final lat = (p['lat'] as num?)?.toDouble();
						final lng = (p['lng'] as num?)?.toDouble();
						if (lat == null || lng == null) continue;
						final dist = _distanceText(p);
						markers.add(Marker(
							markerId: MarkerId(d.id),
							position: LatLng(lat, lng),
							infoWindow: InfoWindow(title: p['name']?.toString() ?? 'Provider', snippet: dist.isEmpty ? null : dist),
						));
						center ??= LatLng(lat, lng);
					}
					if (docs.isEmpty) return Center(child: Text('No ${_title.toLowerCase()} providers found'));
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
									return GoogleMap(
										initialCameraPosition: CameraPosition(target: center!, zoom: 12),
										markers: markers,
										myLocationEnabled: false,
										compassEnabled: false,
									);
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
									final p = docs[i].data();
									final id = docs[i].id;
									final dist = _distanceText(p);
									return ListTile(
										leading: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
											future: FirebaseFirestore.instance.collection('provider_profiles').where('userId', isEqualTo: id).limit(1).get(const GetOptions(source: Source.server)).then((s) => s.docs.isNotEmpty ? s.docs.first.reference.get() : Future.value(null)),
											builder: (context, profSnap) {
												String? img;
												try { final data = profSnap.data?.data() ?? {}; img = ((data['metadata'] as Map?)?['publicImageUrl'] ?? '').toString(); } catch (_) {}
												return CircleAvatar(backgroundImage: (img != null && img!.isNotEmpty) ? NetworkImage(img!) : null, child: (img == null || img!.isEmpty) ? const Icon(Icons.business) : null);
											},
										),
										title: Text(p['name'] ?? 'Provider'),
										subtitle: Text([p['title']?.toString() ?? '', if (dist.isNotEmpty) dist].where((e) => e.isNotEmpty).join(' • ')),
										trailing: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: id))), child: const Text('View')),
									);
								},
							),
						),
					]);
				},
			),
		);
	}
}