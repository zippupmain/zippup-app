import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:zippup/core/config/flags_service.dart';

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
	String? _serviceType; // New: Specific service type
	String? _serviceSubtype; // New: Specific service sub-type
	String _status = 'active';
	String _type = 'individual';
	bool _saving = false;

	// KYC/public/admin details
	final _driverName = TextEditingController();
	final _plateNumber = TextEditingController();
	final List<Uint8List> _vehiclePhotos360 = [];

	// Service type mappings (same as apply provider form)
	final Map<String, List<String>> _subcategories = const {
		'transport': ['Taxi', 'Bike', 'Bus', 'Tricycle', 'Courier'],
		'moving': ['Truck', 'Backie/Pickup', 'Courier'],
		'hire': ['Home Services', 'Tech Services', 'Construction', 'Auto Services', 'Personal Care'],
		'emergency': ['Ambulance', 'Fire Service', 'Security', 'Towing', 'Roadside'],
		'personal': ['Beauty Services', 'Wellness Services', 'Fitness Services', 'Tutoring Services', 'Cleaning Services', 'Childcare Services'],
		'others': ['Events Planning', 'Tutoring', 'Education', 'Creative Services', 'Business Services', 'Event Ticketing'],
	};

	final Map<String, Map<String, List<String>>> _serviceTypes = const {
		'transport': {
			'Taxi': ['2 Seater Car', '4 Seater Car', '6 Seater Car', '8+ Seater Car', 'Luxury Car', 'Economy Car'],
			'Bike': ['Standard Motorbike', 'Power Bike', 'Scooter', 'Electric Bike'],
			'Bus': ['Mini Bus (14 seats)', 'Standard Bus (25 seats)', 'Large Bus (40+ seats)', 'Charter Bus'],
			'Tricycle': ['Standard Tricycle', 'Cargo Tricycle'],
			'Courier': ['Motorbike Courier', 'Car Courier', 'Bicycle Courier'],
		},
		'hire': {
			'Home Services': ['Plumber', 'Electrician', 'Carpenter', 'Painter', 'Cleaner', 'Gardener'],
			'Tech Services': ['Phone Repair', 'Computer Repair', 'TV Repair', 'Appliance Repair', 'CCTV Install'],
			'Construction': ['Builder', 'Mason', 'Welder', 'Roofer', 'Tiler'],
			'Auto Services': ['Mechanic', 'Auto Electrician', 'Panel Beater', 'Tyre Service'],
			'Personal Care': ['Barber', 'Hairdresser', 'Makeup Artist', 'Nail Technician'],
		},
		'emergency': {
			'Ambulance': ['Basic Life Support', 'Advanced Life Support', 'Critical Care', 'Patient Transport'],
			'Fire Service': ['Fire Fighting', 'Rescue Operations', 'Hazmat Response'],
			'Security': ['Armed Response', 'Patrol Service', 'Alarm Response', 'VIP Protection'],
			'Towing': ['Light Vehicle Towing', 'Heavy Vehicle Towing', 'Motorcycle Towing'],
			'Roadside': ['Battery Jump', 'Tire Change', 'Fuel Delivery', 'Lockout Service'],
		},
		'personal': {
			'Beauty Services': ['Hair Styling', 'Hair Cutting', 'Hair Coloring', 'Manicure', 'Pedicure', 'Facial', 'Makeup'],
			'Wellness Services': ['Massage Therapy', 'Spa Treatment', 'Aromatherapy', 'Reflexology'],
			'Fitness Services': ['Personal Training', 'Yoga Instruction', 'Pilates', 'Nutrition Coaching'],
			'Tutoring Services': ['Academic Tutoring', 'Language Teaching', 'Music Lessons', 'Art Lessons'],
			'Cleaning Services': ['House Cleaning', 'Office Cleaning', 'Deep Cleaning', 'Post-Construction Cleaning'],
			'Childcare Services': ['Babysitting', 'Nanny Service', 'Daycare', 'After-School Care'],
		},
	};

	final Map<String, Map<String, Map<String, List<String>>>> _serviceSubtypes = const {
		'emergency': {
			'Ambulance': {
				'Basic Life Support': ['Standard Priority', 'High Priority', 'Critical Priority'],
				'Advanced Life Support': ['Standard Priority', 'High Priority', 'Critical Priority'],
				'Critical Care': ['High Priority', 'Critical Priority'],
				'Patient Transport': ['Standard Priority', 'Scheduled Transport'],
			},
		},
	};
	Uint8List? _driverLicenseBytes;
	Uint8List? _vehiclePapersBytes;
	Uint8List? _trafficRegisterBytes;
	Uint8List? _operationalLicenseBytes; // food/grocery
	bool _inspectionRequired = false; // admin-only flag (prepared)

	// Public images
	Uint8List? _publicImageBytes;
	Uint8List? _bannerImageBytes;

	// Updated to match _subcategories structure for consistency
	final Map<String, List<String>> _cats = const {
		'transport': ['Taxi', 'Bike', 'Bus', 'Tricycle', 'Courier'],
		'moving': ['Truck', 'Backie/Pickup', 'Courier'],
		'hire': ['Home Services', 'Tech Services', 'Construction', 'Auto Services', 'Personal Care'],
		'emergency': ['Ambulance', 'Fire Service', 'Security', 'Towing', 'Roadside'],
		'personal': ['Beauty Services', 'Wellness Services', 'Fitness Services', 'Tutoring Services', 'Cleaning Services', 'Childcare Services'],
		'others': ['Events Planning', 'Tutoring', 'Education', 'Creative Services', 'Business Services', 'Event Ticketing'],
		'food': ['Fast Food', 'Local', 'Pizza', 'Continental', 'Desserts', 'Drinks'],
		'groceries': ['Grocery Store'],
		'rentals': ['Vehicle', 'Houses', 'Other rentals'],
		'marketplace': ['Electronics', 'Vehicles', 'Property', 'Fashion', 'Jobs', 'Services'],
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

	Widget _publicImagesSection() {
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			const Divider(),
			const Text('Public profile images', style: TextStyle(fontWeight: FontWeight.w600)),
			const SizedBox(height: 8),
			Row(children: [
				Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _publicImageBytes = b); }, icon: const Icon(Icons.account_circle), label: Text(_publicImageBytes == null ? 'Upload public image / logo' : 'Public image selected'))),
			]),
			if (_publicImageBytes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Container(height: 80, color: Colors.black12, child: const Center(child: Icon(Icons.image)))) ,
			const SizedBox(height: 8),
			Row(children: [
				Expanded(child: OutlinedButton.icon(onPressed: () async { final b = await _pickImage(); if (b != null) setState(() => _bannerImageBytes = b); }, icon: const Icon(Icons.photo_size_select_large), label: Text(_bannerImageBytes == null ? 'Upload banner / cover' : 'Banner selected'))),
			]),
			if (_bannerImageBytes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Container(height: 80, color: Colors.black12, child: const Center(child: Icon(Icons.panorama)))) ,
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
			final bool bypass = await FlagsService.instance.bypassKyc();
			// Upload KYC files
			final storage = FirebaseStorage.instance;
			Future<String> _put(String path, String name, Uint8List bytes) async {
				final ref = storage.ref('$path/${DateTime.now().millisecondsSinceEpoch}_$name.jpg');
				await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
				return await ref.getDownloadURL();
			}

			// Public images upload first so URLs are available for both docs
			String? publicImageUrl;
			String? bannerUrl;
			if (_publicImageBytes != null) publicImageUrl = await _put('public/$uid', 'public_image', _publicImageBytes!);
			if (_bannerImageBytes != null) bannerUrl = await _put('public/$uid', 'banner', _bannerImageBytes!);

			// Write business profile (for admin management)
			await FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').add({
				'title': _title.text.trim(),
				'description': _desc.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'serviceType': _serviceType, // New: Specific service type
				'serviceSubtype': _serviceSubtype, // New: Specific service sub-type
				'type': _type,
				'status': 'active',
				'createdAt': nowIso,
				'publicImageUrl': publicImageUrl,
				'bannerUrl': bannerUrl,
				'kycBypassed': bypass,
			});
			// Upload KYC files
			final uploads = <String, String>{};
			if (_driverLicenseBytes != null) uploads['driverLicenseUrl'] = await _put('kyc/$uid', 'driver_license', _driverLicenseBytes!);
			if (_vehiclePapersBytes != null) uploads['vehiclePapersUrl'] = await _put('kyc/$uid', 'vehicle_papers', _vehiclePapersBytes!);
			if (_trafficRegisterBytes != null) uploads['trafficRegisterUrl'] = await _put('kyc/$uid', 'traffic_register', _trafficRegisterBytes!);
			final vehiclePhotoUrls = <String>[];
			for (final b in _vehiclePhotos360) { vehiclePhotoUrls.add(await _put('kyc/$uid', 'vehicle_360', b)); }
			if (_operationalLicenseBytes != null) uploads['operationalLicenseUrl'] = await _put('kyc/$uid', 'operational_license', _operationalLicenseBytes!);

			final catLower = (service).toLowerCase();
			final requiresAdmin = ['transport','moving','emergency','food','grocery'].contains(catLower);
			final initialStatus = (requiresAdmin && !bypass) ? 'pending_review' : 'active';

			// Create provider profile for Provider Hub
			try {
				await FirebaseFirestore.instance.collection('provider_profiles').add({
					'userId': uid,
					'service': service,
					'subcategory': _subcategory, // For notification targeting
					'serviceType': _serviceType, // For granular notification targeting
					'serviceSubtype': _serviceSubtype, // For ultra-specific targeting
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
						'serviceType': _serviceType, // New: Specific service type
						'serviceSubtype': _serviceSubtype, // New: Specific service sub-type
						'type': _type,
						'publicImageUrl': publicImageUrl,
						'bannerUrl': bannerUrl,
						'publicDetails': {
							'driverName': _driverName.text.trim().isEmpty ? null : _driverName.text.trim(),
							'plateNumber': _plateNumber.text.trim().isEmpty ? null : _plateNumber.text.trim(),
							'vehiclePhotos360': vehiclePhotoUrls,
						},
						'adminDocs': uploads,
						'inspectionRequired': _inspectionRequired,
						'kycStatus': requiresAdmin ? (bypass ? 'bypassed' : 'submitted') : 'n/a',
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
					onChanged: (v) => setState(() { 
						_category = v; 
						_subcategory = null; 
						_serviceType = null; 
						_serviceSubtype = null; 
					}),
				),
				if (subs.isNotEmpty)
					DropdownButtonFormField<String>(
						value: _subcategory,
						items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
						decoration: const InputDecoration(labelText: 'Subcategory'),
						onChanged: (v) => setState(() { 
							_subcategory = v; 
							_serviceType = null; 
							_serviceSubtype = null; 
						}),
					),
				
				// Service Type dropdown (more specific)
				if (_subcategory != null && _serviceTypes[_category]?[_subcategory] != null)
					DropdownButtonFormField<String>(
						value: _serviceType,
						items: _serviceTypes[_category]![_subcategory]!
							.map((type) => DropdownMenuItem(value: type, child: Text(type)))
							.toList(),
						decoration: const InputDecoration(
							labelText: 'Service Type',
							helperText: 'Specific service you provide (e.g., 4 Seater Car, Plumber)',
						),
						onChanged: (v) => setState(() { 
							_serviceType = v; 
							_serviceSubtype = null; 
						}),
					),
				
				// Service Sub-type dropdown (most specific)
				if (_serviceType != null && 
					_serviceSubtypes[_category]?[_subcategory]?[_serviceType] != null)
					DropdownButtonFormField<String>(
						value: _serviceSubtype,
						items: _serviceSubtypes[_category]![_subcategory]![_serviceType]!
							.map((subtype) => DropdownMenuItem(value: subtype, child: Text(subtype)))
							.toList(),
						decoration: const InputDecoration(
							labelText: 'Service Sub-type',
							helperText: 'Priority level or specialization',
						),
						onChanged: (v) => setState(() => _serviceSubtype = v),
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
				// Debug information card
				Card(
					color: Colors.green.shade50,
					child: Padding(
						padding: const EdgeInsets.all(12),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text('🔍 Business Profile Debug:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
								Text('Category: $_category'),
								Text('Sub-category: $_subcategory'),
								Text('Service Type: $_serviceType'),
								Text('Service Sub-type: $_serviceSubtype'),
								Text('Available Service Types: ${_serviceTypes[_category]?[_subcategory]?.length ?? 0}'),
								if (_serviceTypes[_category]?[_subcategory] != null)
									Text('Types: ${_serviceTypes[_category]![_subcategory]!.join(", ")}'),
							],
						),
					),
				),
				const SizedBox(height: 8),
				
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Business title')),
				TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
				const SizedBox(height: 12),
				_publicImagesSection(),
				_kycSection(),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create')),
			]),
		);
	}
}

