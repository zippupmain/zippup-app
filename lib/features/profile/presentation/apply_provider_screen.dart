import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zippup/common/widgets/address_field.dart';

class ApplyProviderScreen extends StatefulWidget {
	const ApplyProviderScreen({super.key});
	@override
	State<ApplyProviderScreen> createState() => _ApplyProviderScreenState();
}

class _ApplyProviderScreenState extends State<ApplyProviderScreen> {
	final _name = TextEditingController();
	final _address = TextEditingController();
	final _title = TextEditingController();
	String _category = 'transport';
	String? _subcategory;
	String _type = 'individual';
	File? _idDoc;
	File? _bizDoc;
	Uint8List? _idBytes;
	Uint8List? _bizBytes;
	bool _saving = false;
	// Vehicle details for Ride & Moving
	final _vehicleBrand = TextEditingController();
	final _vehicleColor = TextEditingController();
	final _vehiclePlate = TextEditingController();
	final _vehicleModel = TextEditingController();
	final List<Uint8List> _vehiclePhotos = [];
	final List<File> _vehiclePhotoFiles = [];
	// Rentals hierarchy state and extra fields
	String? _rentalSubtype;
	final _description = TextEditingController();
	final _size = TextEditingController();

	final Map<String, List<String>> _subcategories = const {
		'transport': ['Taxi', 'Bike', 'Bus', 'Tricycle', 'Courier'],
		'moving': ['Truck', 'Backie/Pickup', 'Courier'],
		'rentals': ['Vehicle', 'Houses', 'Other rentals'],
		'food': ['Fast Food', 'Local', 'Grocery'],
		'groceries': ['Grocery Store'],
		'hire': ['Home', 'Tech', 'Construction', 'Auto', 'Personal'],
		'marketplace': ['Electronics', 'Vehicles', 'Property', 'Fashion', 'Jobs', 'Services'],
		'emergency': ['Ambulance', 'Fire Service', 'Security', 'Towing', 'Roadside'],
		'personal': ['Makeup', 'Hair', 'Nails', 'Pedicure', 'Massage', 'Barbing', 'Hair styling'],
		'others': ['Events planning', 'Live event tickets', 'Tutors'],
	};

	Future<void> _pickVehiclePhotos() async {
		final picker = ImagePicker();
		final images = await picker.pickMultiImage(imageQuality: 85);
		if (images.isEmpty) return;
		for (final img in images) {
			try { _vehiclePhotos.add(await img.readAsBytes()); }
			catch (_) { _vehiclePhotoFiles.add(File(img.path)); }
		}
		setState(() {});
	}

	Future<void> _pickId() async {
		final idPick = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (idPick != null) {
			try { _idBytes = await idPick.readAsBytes(); _idDoc = null; }
			catch (_) { _idDoc = File(idPick.path); _idBytes = null; }
		}
		setState(() {});
	}
	Future<void> _pickBiz() async {
		final bizPick = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (bizPick != null) {
			try { _bizBytes = await bizPick.readAsBytes(); _bizDoc = null; }
			catch (_) { _bizDoc = File(bizPick.path); _bizBytes = null; }
		}
		setState(() {});
	}

	Future<void> _submit() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser!.uid;
			String? idUrl;
			String? bizUrl;
			final List<String> vehicleUrls = [];
			if (_idBytes != null || _idDoc != null) {
				final ref = FirebaseStorage.instance.ref('providers/$uid/id.jpg');
				if (_idBytes != null) await ref.putData(_idBytes!, SettableMetadata(contentType: 'image/jpeg'));
				else await ref.putFile(_idDoc!);
				idUrl = await ref.getDownloadURL();
			}
			if (_bizBytes != null || _bizDoc != null) {
				final ref = FirebaseStorage.instance.ref('providers/$uid/biz.jpg');
				if (_bizBytes != null) await ref.putData(_bizBytes!, SettableMetadata(contentType: 'image/jpeg'));
				else await ref.putFile(_bizDoc!);
				bizUrl = await ref.getDownloadURL();
			}
			// Upload vehicle photos if applicable
			if (['transport','moving','rentals'].contains(_category) && (_vehiclePhotos.isNotEmpty || _vehiclePhotoFiles.isNotEmpty)) {
				for (int i = 0; i < _vehiclePhotos.length; i++) {
					final ref = FirebaseStorage.instance.ref('applications/$uid/vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
					await ref.putData(_vehiclePhotos[i], SettableMetadata(contentType: 'image/jpeg'));
					vehicleUrls.add(await ref.getDownloadURL());
				}
				for (int j = 0; j < _vehiclePhotoFiles.length; j++) {
					final ref = FirebaseStorage.instance.ref('applications/$uid/vehicle_file_${DateTime.now().millisecondsSinceEpoch}_$j.jpg');
					await ref.putFile(_vehiclePhotoFiles[j]);
					vehicleUrls.add(await ref.getDownloadURL());
				}
			}
			await FirebaseFirestore.instance.collection('applications').doc(uid).set({
				'applicantId': uid,
				'name': _name.text.trim(),
				'address': _address.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'rentalSubtype': _rentalSubtype,
				'type': _type,
				'title': _title.text.trim(),
				'idUrl': idUrl,
				'bizUrl': bizUrl,
				'vehicleBrand': _vehicleBrand.text.trim().isEmpty ? null : _vehicleBrand.text.trim(),
				'vehicleColor': _vehicleColor.text.trim().isEmpty ? null : _vehicleColor.text.trim(),
				'vehiclePlate': _vehiclePlate.text.trim().isEmpty ? null : _vehiclePlate.text.trim(),
				'vehicleModel': _vehicleModel.text.trim().isEmpty ? null : _vehicleModel.text.trim(),
				'vehiclePhotoUrls': vehicleUrls,
				'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
				'size': _size.text.trim().isEmpty ? null : _size.text.trim(),
				'status': 'pending',
				'createdAt': DateTime.now().toIso8601String(),
			});
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted')));
				Navigator.pop(context);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
			}
		} finally {
			setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final subs = _subcategories[_category] ?? const <String>[];
		return Scaffold(
			appBar: AppBar(title: const Text('Apply as Provider / Vendor')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name (as on ID/passport)')),
					AddressField(controller: _address, label: 'Address'),
					DropdownButtonFormField(value: _category, items: const [
						DropdownMenuItem(value: 'transport', child: Text('Transport')),
						DropdownMenuItem(value: 'moving', child: Text('Moving')),
						DropdownMenuItem(value: 'rentals', child: Text('Rentals')),
						DropdownMenuItem(value: 'food', child: Text('Food')),
						DropdownMenuItem(value: 'groceries', child: Text('Groceries')),
						DropdownMenuItem(value: 'hire', child: Text('Hire')),
						DropdownMenuItem(value: 'marketplace', child: Text('Marketplace')),
						DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
						DropdownMenuItem(value: 'personal', child: Text('Personal')),
						DropdownMenuItem(value: 'others', child: Text('Others')),
					], onChanged: (v) => setState(() { _category = v as String; _subcategory = null; _rentalSubtype = null; }), decoration: const InputDecoration(labelText: 'Service category')),
					if (subs.isNotEmpty)
						DropdownButtonFormField<String>(
							value: _subcategory,
							items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
							decoration: const InputDecoration(labelText: 'Sub category'),
							onChanged: (v) => setState(() => _subcategory = v),
						),
					DropdownButtonFormField(value: _type, items: const [
						DropdownMenuItem(value: 'individual', child: Text('Individual')),
						DropdownMenuItem(value: 'company', child: Text('Company')),
					], onChanged: (v) => setState(() => _type = v as String), decoration: const InputDecoration(labelText: 'Type')),
					TextField(controller: _title, decoration: const InputDecoration(labelText: 'Service title')),
					if (_category == 'rentals' && _subcategory == 'Vehicle')
						DropdownButtonFormField<String>(
							value: _rentalSubtype,
							items: const [
								DropdownMenuItem(value: 'Luxury car', child: Text('Luxury car')),
								DropdownMenuItem(value: 'Normal car', child: Text('Normal car')),
								DropdownMenuItem(value: 'Bus', child: Text('Bus')),
								DropdownMenuItem(value: 'Truck', child: Text('Truck')),
								DropdownMenuItem(value: 'Tractor', child: Text('Tractor')),
							],
							onChanged: (v) => setState(() => _rentalSubtype = v),
							decoration: const InputDecoration(labelText: 'Vehicle subtype'),
						),
					if (_category == 'rentals' && _subcategory == 'Houses') ...[
						DropdownButtonFormField<String>(
							value: _rentalSubtype,
							items: const [
								DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
								DropdownMenuItem(value: 'Shortlet', child: Text('Shortlet')),
								DropdownMenuItem(value: 'Event hall', child: Text('Event hall')),
								DropdownMenuItem(value: 'Office space', child: Text('Office space')),
								DropdownMenuItem(value: 'Warehouse', child: Text('Warehouse')),
							],
							onChanged: (v) => setState(() => _rentalSubtype = v),
							decoration: const InputDecoration(labelText: 'Property subtype'),
						),
						TextField(controller: _title, decoration: const InputDecoration(labelText: 'Listing title')),
						TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
						TextField(controller: _size, decoration: const InputDecoration(labelText: 'Size (e.g., 3-bedroom / 120sqm)')),
					],
					if (_category == 'rentals' && _subcategory == 'Other rentals') ...[
						DropdownButtonFormField<String>(
							value: _rentalSubtype,
							items: const [
								DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
								DropdownMenuItem(value: 'Instruments', child: Text('Instruments')),
								DropdownMenuItem(value: 'Party items', child: Text('Party items')),
								DropdownMenuItem(value: 'Tools', child: Text('Tools')),
							],
							onChanged: (v) => setState(() => _rentalSubtype = v),
							decoration: const InputDecoration(labelText: 'Other subtype'),
						),
						TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
						TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
					],
					if (_category == 'transport' || _category == 'moving' || (_category == 'rentals' && _subcategory == 'Vehicle')) ...[
						const SizedBox(height: 8),
						const Text('Vehicle details', style: TextStyle(fontWeight: FontWeight.bold)),
						TextField(controller: _vehicleBrand, decoration: const InputDecoration(labelText: 'Brand / make')),
						TextField(controller: _vehicleColor, decoration: const InputDecoration(labelText: 'Color')),
						TextField(controller: _vehiclePlate, decoration: const InputDecoration(labelText: 'Plate number')),
						TextField(controller: _vehicleModel, decoration: const InputDecoration(labelText: 'Model (e.g., 911 Mercedes)')),
						ListTile(title: const Text('Upload 360° vehicle photos (multi-select)'), trailing: const Icon(Icons.upload_file), onTap: _pickVehiclePhotos, subtitle: Text('${_vehiclePhotos.length + _vehiclePhotoFiles.length} selected')),
					],
					const SizedBox(height: 8),
					ListTile(title: const Text('Upload ID/Passport'), trailing: const Icon(Icons.upload_file), onTap: _pickId, subtitle: Text(_idDoc?.path.split('/').last ?? (_idBytes != null ? 'Selected' : 'Not uploaded'))),
					ListTile(title: const Text('Upload business document (registration/permits)'), trailing: const Icon(Icons.upload_file), onTap: _pickBiz, subtitle: Text(_bizDoc?.path.split('/').last ?? (_bizBytes != null ? 'Selected' : 'Not uploaded'))),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _submit, child: const Text('Submit application')),
				],
			),
		);
	}
}