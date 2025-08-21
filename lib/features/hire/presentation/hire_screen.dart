import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/profile/presentation/provider_profile_screen.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zippup/common/widgets/address_field.dart';

class HireScreen extends StatefulWidget {
	const HireScreen({super.key, this.initialCategory, this.initialQuery});
	final String? initialCategory;
	final String? initialQuery;

	@override
	State<HireScreen> createState() => _HireScreenState();
}

class _HireScreenState extends State<HireScreen> {
	String _filter = 'home';
	final TextEditingController _search = TextEditingController();
	String _q = '';
	geo.Position? _me;
	final TextEditingController _dest = TextEditingController();

	final Map<String, List<String>> _examples = const {
		'home': ['Cleaning', 'Plumbing', 'Electrician', 'Painting', 'Carpentry', 'Pest control'],
		'tech': ['Phone repair', 'Computer repair', 'Networking', 'CCTV install', 'Data recovery'],
		'construction': ['Builders', 'Roofing', 'Tiling', 'Welding', 'Scaffolding'],
		'auto': ['Mechanic', 'Tyre replacement', 'Battery jumpstart', 'Fuel delivery'],
		'personal': ['Nails', 'Hair', 'Massage', 'Pedicure', 'Manicure', 'Makeups'],
	};

	@override
	void initState() {
		super.initState();
		if (widget.initialCategory != null) _filter = widget.initialCategory!;
		if (widget.initialQuery != null) {
			_q = widget.initialQuery!.toLowerCase();
			_search.text = widget.initialQuery!;
		}
		_location();
	}

	Future<void> _location() async {
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
			appBar: AppBar(title: const Text('Hire'), backgroundColor: Colors.white, foregroundColor: Colors.black),
			backgroundColor: Colors.white,
			body: Column(
				children: [
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						padding: const EdgeInsets.all(8),
						child: Wrap(spacing: 8, children: [
							ChoiceChip(label: const Text('Home'), selected: _filter == 'home', onSelected: (_) => setState(() => _filter = 'home')),
							ChoiceChip(label: const Text('Tech'), selected: _filter == 'tech', onSelected: (_) => setState(() => _filter = 'tech')),
							ChoiceChip(label: const Text('Construction'), selected: _filter == 'construction', onSelected: (_) => setState(() => _filter = 'construction')),
							ChoiceChip(label: const Text('Auto'), selected: _filter == 'auto', onSelected: (_) => setState(() => _filter = 'auto')),
							ChoiceChip(label: const Text('Personal'), selected: _filter == 'personal', onSelected: (_) => setState(() => _filter = 'personal')),
						]),
					),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16.0),
						child: TextField(
							controller: _search,
							decoration: const InputDecoration(
								labelText: 'Search providers',
								prefixIcon: Icon(Icons.search),
							),
							onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
						),
					),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16.0),
						child: Align(
							alignment: Alignment.centerLeft,
							child: Text(
								'Examples: ${( _examples[_filter] ?? const <String>[] ).join(', ')}',
								style: const TextStyle(fontSize: 12, color: Colors.black54),
							),
						),
					),
					Expanded(
						child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: FirebaseFirestore.instance.collection('providers').where('category', isEqualTo: _filter).snapshots(),
							builder: (context, snap) {
								if (snap.hasError) {
									return Center(child: Text('Error loading providers: ${snap.error}'));
								}
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								final allDocs = snap.data!.docs.where((d) {
									if (_q.isEmpty) return true;
									final name = (d.data()['name'] ?? '').toString().toLowerCase();
									final title = (d.data()['title'] ?? '').toString().toLowerCase();
									return name.contains(_q) || title.contains(_q);
								}).toList();

								// Build map markers
								final markers = <Marker>{};
								LatLng? center;
								if (_me != null) center = LatLng(_me!.latitude, _me!.longitude);
								for (final d in allDocs) {
									final p = d.data();
									final lat = (p['lat'] as num?)?.toDouble();
									final lng = (p['lng'] as num?)?.toDouble();
									if (lat == null || lng == null) continue;
									final dist = _distanceText(p);
									final id = d.id;
									markers.add(Marker(
										markerId: MarkerId(id),
										position: LatLng(lat, lng),
										infoWindow: InfoWindow(title: p['name']?.toString() ?? 'Provider', snippet: dist.isEmpty ? null : dist),
									));
									center ??= LatLng(lat, lng);
								}

								return Column(children: [
									SizedBox(
										height: 220,
										child: Builder(builder: (context) {
											if (center == null) return const Center(child: Text('Map: no location yet'));
											try {
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
									Padding(
										padding: const EdgeInsets.symmetric(horizontal:16, vertical:8),
										child: Column(children:[
											AddressField(controller: _dest, label: 'Destination address'),
										]),
									),
									Expanded(
										child: ListView.separated(
											itemCount: allDocs.length,
											separatorBuilder: (_, __) => const Divider(height: 1),
											itemBuilder: (context, i) {
												final p = allDocs[i].data();
												final pid = allDocs[i].id;
												final dist = _distanceText(p);
												return ListTile(
													title: Text(p['name'] ?? 'Provider', style: const TextStyle(color: Colors.black)),
													subtitle: Text('Rating: ${(p['rating'] ?? 0).toString()} • Fee: ₦${(p['fee'] ?? 0).toString()}${dist.isNotEmpty ? ' • $dist' : ''}', style: const TextStyle(color: Colors.black54)),
													trailing: Wrap(spacing: 8, children: [
														TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: pid))), child: const Text('Profile')),
														FilledButton(onPressed: () async {
															final daddr=_dest.text.trim();
															if(daddr.isEmpty){
																ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter destination')));
																return;
															}
															final cls = await showDialog<String>(context: context, builder: (ctx){
																return SimpleDialog(title: const Text('Choose service class'), children:[
																	SimpleDialogOption(onPressed: ()=> Navigator.pop(ctx,'Basic'), child: const Text('Basic • ₦2,000 / 2hrs')),
																	SimpleDialogOption(onPressed: ()=> Navigator.pop(ctx,'Standard'), child: const Text('Standard • ₦3,500 / 2hrs')),
																	SimpleDialogOption(onPressed: ()=> Navigator.pop(ctx,'Pro'), child: const Text('Pro • ₦5,000 / 2hrs')),
																]);
															});
															if (cls == null) return;
															showDialog(context: context, barrierDismissible: false, builder: (ctx)=> AlertDialog(
																title: Text('Finding $cls ${_filter}…'),
																content: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
																actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel'))],
															));
															await Future.delayed(const Duration(seconds: 8));
															if (!mounted) return;
															Navigator.of(context).pop();
															Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: pid)));
														}, child: const Text('Book')),
													]),
												);
										},
									),
									),
								]);
						},
						),
					),
				],
			),
		);
	}
}