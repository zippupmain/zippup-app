import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class CreateServiceProfileScreen extends StatefulWidget {
	final String? profileId;
	const CreateServiceProfileScreen({super.key, this.profileId});
	@override
	State<CreateServiceProfileScreen> createState() => _CreateServiceProfileScreenState();
}

class _CreateServiceProfileScreenState extends State<CreateServiceProfileScreen> {
	final _title = TextEditingController();
	final _desc = TextEditingController();
	String? _category = 'transport';
	String? _subcategory;
	String _status = 'active';
	String _type = 'individual';
	bool _saving = false;

	// KYC/public/admin details
	final _driverName = TextEditingController();
	final _plateNumber = TextEditingController();
	final List<Uint8List> _vehiclePhotos360 = [];
	Uint8List? _driverLicenseBytes;
	Uint8List? _vehiclePapersBytes;
	Uint8List? _trafficRegisterBytes;
	Uint8List? _operationalLicenseBytes; // food/grocery
	bool _inspectionRequired = false; // admin-only flag (prepared)

	final Map<String, List<String>> _cats = const {
		'transport': ['Taxi','Bike','Tricycle','Bus','Courier','Driver'],
		'moving': ['Truck','Pickup/Backie','Courier'],
		'food': ['Restaurant','Fast Food','Local','Bakery','Drinks'],
		'grocery': ['Grocery store'],
		'delivery': ['Food & Grocery courier'],
		'hire': ['Plumbing','Electrical','Carpentry','Painting','AC/Fridge','Auto mechanic','Cleaning','IT/Computer','Beauty'],
		'emergency': ['Ambulance','Fire','Security','Towing','Roadside'],
		'rentals': ['Vehicle','Houses','Other rentals'],
		'marketplace': ['Electronics','Vehicles','Property','Fashion','Services','Jobs'],
		'personal': ['Nails','Hair','Massage','Pedicure','Makeups'],
		'others': ['Events','Tickets','Tutors'],
	};

	Future<Uint8List?> _pickImage() async {
		final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (x == null) return null;
		return await x.readAsBytes();
	}

	Widget _kycSection() {
		final cat = (_category ?? '').toLowerCase();
		final needsVehicle = ['transport','moving','emergency'].contains(cat);
		final needsFoodDocs = ['food','grocery'].contains(cat);
		if (!needsVehicle && !needsFoodDocs) return const SizedBox.shrink();
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			const Divider(),
			const Text('KYC / Compliance', style: TextStyle(fontWeight: FontWeight.w600)),
			const SizedBox(height: 8),
			if (needsVehicle) ...[
				TextField(controller: _driverName, decoration: const InputDecoration(labelText: 'Driver name (public)')),
				TextField(controller: _plateNumber, decoration: const InputDecoration(labelText: 'Plate number (public)')),
				const SizedBox(height: 8),
				Wrap(spacing: 8, runSpacing: 8, children: [
					..._vehiclePhotos360.map((b) => Container(width: 64, height: 64, color: Colors.black12, child: const Icon(Icons.photo))),
					OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _vehiclePhotos360.add(b)); }, icon: const Icon(Icons.add_a_photo), label: const Text('Add 360° photo')),
				]),
				const SizedBox(height: 8),
				Row(children: [
					Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _driverLicenseBytes = b); }, icon: const Icon(Icons.badge), label: Text(_driverLicenseBytes == null ? 'Upload driver license (admin)' : 'Driver license selected'))),
				]),
				Row(children: [
					Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _vehiclePapersBytes = b); }, icon: const Icon(Icons.description), label: Text(_vehiclePapersBytes == null ? 'Upload vehicle papers (admin)' : 'Vehicle papers selected'))),
				]),
				Row(children: [
					Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _trafficRegisterBytes = b); }, icon: const Icon(Icons.folder), label: Text(_trafficRegisterBytes == null ? 'Upload traffic register (admin)' : 'Traffic register selected'))),
				]),
			],
			if (needsFoodDocs) ...[
				Row(children: [
					Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _operationalLicenseBytes = b); }, icon: const Icon(Icons.verified), label: Text(_operationalLicenseBytes == null ? 'Upload operational license' : 'Operational license selected'))),
				]),
			],
		]);
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) {
				if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first')));
				return;
			}
			final uid = user.uid;
			final nowIso = DateTime.now().toIso8601String();
			final service = (_category ?? 'transport');
			// Write business profile (for admin management)
			await FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').add({
				'title': _title.text.trim(),
				'description': _desc.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'type': _type,
				'status': 'active',
				'createdAt': nowIso,
			});
			// Upload KYC files
			final storage = FirebaseStorage.instance;
			final uploads = <String, String>{};
			Future<String> _put(String name, Uint8List bytes) async {
				final ref = storage.ref('kyc/$uid/${DateTime.now().millisecondsSinceEpoch}_$name.jpg');
				await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
				return await ref.getDownloadURL();
			}
			if (_driverLicenseBytes != null) uploads['driverLicenseUrl'] = await _put('driver_license', _driverLicenseBytes!);
			if (_vehiclePapersBytes != null) uploads['vehiclePapersUrl'] = await _put('vehicle_papers', _vehiclePapersBytes!);
			if (_trafficRegisterBytes != null) uploads['trafficRegisterUrl'] = await _put('traffic_register', _trafficRegisterBytes!);
			final vehiclePhotoUrls = <String>[];
			for (final b in _vehiclePhotos360) { vehiclePhotoUrls.add(await _put('vehicle_360', b)); }
			if (_operationalLicenseBytes != null) uploads['operationalLicenseUrl'] = await _put('operational_license', _operationalLicenseBytes!);

			final catLower = (service).toLowerCase();
			final requiresAdmin = ['transport','moving','emergency','food','grocery'].contains(catLower);
			final initialStatus = requiresAdmin ? 'pending_review' : 'active';

			// Create provider profile for Provider Hub
			try {
				await FirebaseFirestore.instance.collection('provider_profiles').add({
					'userId': uid,
					'service': service,
					'status': initialStatus,
					'availabilityOnline': false,
					'rating': 0.0,
					'totalRatings': 0,
					'earnings': 0.0,
					'createdAt': nowIso,
					'metadata': {
						'title': _title.text.trim(),
						'description': _desc.text.trim(),
						'category': _category,
						'subcategory': _subcategory,
						'type': _type,
						'publicDetails': {
							'driverName': _driverName.text.trim().isEmpty ? null : _driverName.text.trim(),
							'plateNumber': _plateNumber.text.trim().isEmpty ? null : _plateNumber.text.trim(),
							'vehiclePhotos360': vehiclePhotoUrls,
						},
						'adminDocs': uploads,
						'inspectionRequired': _inspectionRequired,
						'kycStatus': requiresAdmin ? 'submitted' : 'n/a',
					},
				});
			} catch (_) {}
			// Try to set user provider roles; ignore failures
			try {
				await FirebaseFirestore.instance.collection('users').doc(uid).set({
					'providerRoles': FieldValue.arrayUnion(['provider:$service']),
					'activeRole': 'provider:$service',
				}, SetOptions(merge: true));
			} catch (_) {}
			// Ensure role is switched via Cloud Function (bypasses client rules)
			try {
				final fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('switchActiveRole');
				await fn.call({'role': 'provider:$service'});
			} catch (_) {}
			if (!mounted) return;
			// Go to Hub
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile created')));
			context.go('/hub');
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
			}
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final subs = _category == null ? const <String>[] : (_cats[_category] ?? const <String>[]);
		return Scaffold(
			appBar: AppBar(title: const Text('Create business profile')),
			body: ListView(padding: const EdgeInsets.all(16), children: [
				DropdownButtonFormField<String>(
					value: _category,
					items: _cats.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
					decoration: const InputDecoration(labelText: 'Category'),
					onChanged: (v) => setState(() { _category = v; _subcategory = null; }),
				),
				if (subs.isNotEmpty)
					DropdownButtonFormField<String>(
						value: _subcategory,
						items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
						decoration: const InputDecoration(labelText: 'Subcategory'),
						onChanged: (v) => setState(() => _subcategory = v),
					),
				DropdownButtonFormField<String>(
					value: _type,
					items: const [
						DropdownMenuItem(value: 'individual', child: Text('Individual')),
						DropdownMenuItem(value: 'company', child: Text('Company')),
					],
					decoration: const InputDecoration(labelText: 'Type'),
					onChanged: (v) => setState(() => _type = v ?? 'individual'),
				),
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Business title')),
				TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
				const SizedBox(height: 12),
				_kycSection(),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create')),
			]),
		);
	}
}

