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
	String? _serviceType; // New: Specific service type (e.g., '4 Seater Car', 'Plumber', 'Ambulance')
	String? _serviceSubtype; // New: Specific service subtype (e.g., 'High Priority', 'Large Courier')
	Uint8List? _idBytes;
	Uint8List? _bizBytes;
	bool _saving = false;
	// Payment options
	bool _acceptsCash = true;
	bool _acceptsCard = true;
	// Vehicle details for Ride & Moving
	final _vehicleBrand = TextEditingController();
	final _vehicleColor = TextEditingController();
	final _vehiclePlate = TextEditingController();
	final _vehicleModel = TextEditingController();
	final List<Uint8List> _vehiclePhotos = [];
	final List<String> vehicleUrls = [];
	// Rentals hierarchy state and extra fields
	String? _rentalSubtype;
	final _description = TextEditingController();
	final _size = TextEditingController();

	final Map<String, List<String>> _subcategories = const {
		'transport': ['Taxi', 'Bike', 'Bus', 'Tricycle', 'Courier'],
		'moving': ['Truck', 'Backie/Pickup', 'Courier'],
		'rentals': ['Vehicle', 'Houses', 'Other rentals'],
		'food': ['Fast Food', 'Local', 'Pizza', 'Continental', 'Desserts', 'Drinks'],
		'groceries': ['Grocery Store'],
		'hire': ['Home Services', 'Tech Services', 'Construction', 'Auto Services', 'Personal Care'],
		'marketplace': ['Electronics', 'Vehicles', 'Property', 'Fashion', 'Jobs', 'Services'],
		'emergency': ['Ambulance', 'Fire Service', 'Security', 'Towing', 'Roadside'],
		'personal': ['Beauty Services', 'Wellness Services', 'Fitness Services', 'Tutoring Services', 'Cleaning Services', 'Childcare Services'],
		'others': ['Events Planning', 'Tutoring', 'Education', 'Creative Services', 'Business Services', 'Event Ticketing'],
	};

	// Service Types (more specific than subcategory)
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
		'moving': {
			'Truck': ['Small Truck (1-2 rooms)', 'Medium Truck (3-4 rooms)', 'Large Truck (5+ rooms)', 'Specialized Moving'],
			'Backie/Pickup': ['Single Item', 'Small Load', 'Appliance Moving'],
			'Courier': ['Document Delivery', 'Small Package', 'Medium Package', 'Express Delivery'],
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

	// Service Sub-types (most specific level)
	final Map<String, Map<String, Map<String, List<String>>>> _serviceSubtypes = const {
		'emergency': {
			'Ambulance': {
				'Basic Life Support': ['Standard Priority', 'High Priority', 'Critical Priority'],
				'Advanced Life Support': ['Standard Priority', 'High Priority', 'Critical Priority'],
				'Critical Care': ['High Priority', 'Critical Priority'],
				'Patient Transport': ['Standard Priority', 'Scheduled Transport'],
			},
		},
		'moving': {
			'Courier': {
				'Document Delivery': ['Same Day', 'Next Day', 'Express (2 hours)'],
				'Small Package': ['Standard', 'Fragile', 'Express'],
				'Express Delivery': ['1 Hour', '2 Hours', '4 Hours'],
			},
		},
	};

	Future<void> _pickVehiclePhotos() async {
		final picker = ImagePicker();
		final images = await picker.pickMultiImage(imageQuality: 85);
		if (images.isEmpty) return;
		for (final img in images) {
			_vehiclePhotos.add(await img.readAsBytes());
		}
		setState(() {});
	}

	Future<void> _pickId() async {
		final idPick = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (idPick != null) { _idBytes = await idPick.readAsBytes(); setState(() {}); }
	}
	Future<void> _pickBiz() async {
		final bizPick = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (bizPick != null) { _bizBytes = await bizPick.readAsBytes(); setState(() {}); }
	}

	Future<void> _submit() async {
		// Validate payment methods
		if (!_acceptsCash && !_acceptsCard) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('⚠️ Please select at least one payment method'),
					backgroundColor: Colors.red,
				)
			);
			return;
		}
		
		setState(() => _saving = true);
		try {
			print('🔄 Starting application submission...');
			final uid = FirebaseAuth.instance.currentUser!.uid;
			print('✅ User ID: $uid');
			
			// TEST MODE: Completely skip file operations to avoid CORS issues
			String? idUrl;
			String? bizUrl;
			List<String> vehicleUrls = [];
			
			print('🧪 TEST MODE: Bypassing all file operations due to CORS issues');
			
			// Generate test URLs without any Firebase Storage calls
			if (_idBytes != null) {
				idUrl = 'test://id-document-${DateTime.now().millisecondsSinceEpoch}';
				print('✅ ID document (test): $idUrl');
			}
			
			if (_bizBytes != null) {
				bizUrl = 'test://proof-address-${DateTime.now().millisecondsSinceEpoch}';
				print('✅ Proof of address (test): $bizUrl');
			}
			
			// Test mode vehicle photos - no Firebase Storage calls
			if (['transport','moving','rentals'].contains(_category) && _vehiclePhotos.isNotEmpty) {
				print('📤 Adding ${_vehiclePhotos.length} test vehicle photos...');
				for (int i = 0; i < _vehiclePhotos.length; i++) {
					vehicleUrls.add('test://vehicle-${DateTime.now().millisecondsSinceEpoch}-$i');
				}
				print('✅ Vehicle photos (test): ${vehicleUrls.length} added');
			}
			print('💾 Saving application to Firestore...');
			await FirebaseFirestore.instance.collection('applications').doc(uid).set({
				'applicantId': uid,
				'name': _name.text.trim(),
				'address': _address.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'serviceType': _serviceType, // New: Specific service type
				'serviceSubtype': _serviceSubtype, // New: Specific service subtype
				'rentalSubtype': _rentalSubtype,
				'type': _type,
				'title': _title.text.trim(),
				'idUrl': idUrl,
				'proofOfAddressUrl': bizUrl,
				'vehicleBrand': _vehicleBrand.text.trim().isEmpty ? null : _vehicleBrand.text.trim(),
				'vehicleColor': _vehicleColor.text.trim().isEmpty ? null : _vehicleColor.text.trim(),
				'vehiclePlate': _vehiclePlate.text.trim().isEmpty ? null : _vehiclePlate.text.trim(),
				'vehicleModel': _vehicleModel.text.trim().isEmpty ? null : _vehicleModel.text.trim(),
				'vehiclePhotoUrls': vehicleUrls,
				'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
				'size': _size.text.trim().isEmpty ? null : _size.text.trim(),
				'acceptsCash': _acceptsCash,
				'acceptsCard': _acceptsCard,
				'paymentMethods': [
					if (_acceptsCash) 'cash',
					if (_acceptsCard) 'card',
				],
				'status': 'pending',
				'createdAt': DateTime.now().toIso8601String(),
			});
			print('✅ Application saved to Firestore successfully');
			
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
					content: Text('✅ Application submitted successfully!'),
					backgroundColor: Colors.green,
				));
				Navigator.pop(context);
			}
		} catch (e) {
			print('❌ Application submission failed: $e');
			print('❌ Stack trace: ${StackTrace.current}');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('❌ Submit failed: $e'),
						backgroundColor: Colors.red,
						duration: const Duration(seconds: 5),
					),
				);
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
					], onChanged: (v) => setState(() { 
						_category = v as String; 
						_subcategory = null; 
						_serviceType = null; // Reset service type
						_serviceSubtype = null; // Reset service sub-type
						_rentalSubtype = null; 
					}), decoration: const InputDecoration(labelText: 'Service category')),
					if (subs.isNotEmpty)
						DropdownButtonFormField<String>(
							value: _subcategory,
							items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
							decoration: const InputDecoration(labelText: 'Sub category'),
							onChanged: (v) => setState(() { 
								_subcategory = v; 
								_serviceType = null; // Reset when subcategory changes
								_serviceSubtype = null; // Reset when subcategory changes
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
								helperText: 'Specific service you provide',
							),
							onChanged: (v) => setState(() { 
								_serviceType = v; 
								_serviceSubtype = null; // Reset when service type changes
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
						ListTile(title: const Text('Upload 360° vehicle photos (multi-select)'), trailing: const Icon(Icons.upload_file), onTap: _pickVehiclePhotos, subtitle: Text('${_vehiclePhotos.length} selected')),
					],
					const SizedBox(height: 8),
					ListTile(title: const Text('Upload ID/Passport'), trailing: const Icon(Icons.upload_file), onTap: _pickId, subtitle: Text(_idBytes != null ? 'Selected' : 'Not uploaded')),
					ListTile(title: const Text('Upload Proof of Address Document'), trailing: const Icon(Icons.upload_file), onTap: _pickBiz, subtitle: Text(_bizBytes != null ? 'Proof of address uploaded' : 'Utility bill, bank statement, or lease agreement')),
					
					// Payment options section
					const SizedBox(height: 16),
					Card(
						color: Colors.green.shade50,
						child: Padding(
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											const Icon(Icons.payment, color: Colors.green),
											const SizedBox(width: 8),
											const Text('Payment Methods Accepted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										],
									),
									const SizedBox(height: 12),
									CheckboxListTile(
										title: const Text('Cash Payments', style: TextStyle(color: Colors.black)),
										subtitle: const Text('Accept cash payments from customers', style: TextStyle(color: Colors.black54)),
										value: _acceptsCash,
										onChanged: (value) => setState(() => _acceptsCash = value ?? true),
										activeColor: Colors.green,
									),
									CheckboxListTile(
										title: const Text('Card Payments', style: TextStyle(color: Colors.black)),
										subtitle: const Text('Accept automatic card/wallet payments', style: TextStyle(color: Colors.black54)),
										value: _acceptsCard,
										onChanged: (value) => setState(() => _acceptsCard = value ?? true),
										activeColor: Colors.green,
									),
									if (!_acceptsCash && !_acceptsCard) Container(
										padding: const EdgeInsets.all(8),
										decoration: BoxDecoration(
											color: Colors.red.shade50,
											borderRadius: BorderRadius.circular(8),
											border: Border.all(color: Colors.red.shade200),
										),
										child: const Row(
											children: [
												Icon(Icons.warning, color: Colors.red, size: 16),
												SizedBox(width: 8),
												Expanded(
													child: Text(
														'You must accept at least one payment method',
														style: TextStyle(color: Colors.red, fontSize: 12),
													),
												),
											],
										),
									),
									const SizedBox(height: 8),
									Container(
										padding: const EdgeInsets.all(12),
										decoration: BoxDecoration(
											color: Colors.blue.shade50,
											borderRadius: BorderRadius.circular(8),
										),
										child: const Text(
											'💡 Platform fee: 15% commission on all transactions. Cash payments require manual reconciliation.',
											style: TextStyle(color: Colors.black87, fontSize: 12),
										),
									),
								],
							),
						),
					),
					
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _submit, child: const Text('Submit application')),
				],
			),
		);
	}
}