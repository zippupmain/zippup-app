import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class KycOnboardingScreen extends StatefulWidget {
	const KycOnboardingScreen({super.key});

	@override
	State<KycOnboardingScreen> createState() => _KycOnboardingScreenState();
}

class _KycOnboardingScreenState extends State<KycOnboardingScreen> {
	final _name = TextEditingController();
	final _email = TextEditingController();
	final _phone = TextEditingController();
	final _address = TextEditingController();
	String _idType = 'National ID';
	final _idNumber = TextEditingController();
	Uint8List? _idImageBytes;
	File? _idImageFile;
	final List<Uint8List> _proofBytes = [];
	final List<File> _proofFiles = [];
	Uint8List? _selfieBytes;
	File? _selfieFile;
	bool _saving = false;

	Future<void> _pickSingle(ImageSource source, void Function(Uint8List?, File?) setter) async {
		final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
		if (x == null) return;
		try {
			final b = await x.readAsBytes();
			setter(b, null);
		} catch (_) {
			setter(null, File(x.path));
		}
		setState(() {});
	}

	Future<void> _chooseSourceAndPick(void Function(ImageSource) onPick) async {
		final src = await showModalBottomSheet<ImageSource>(
			context: context,
			builder: (context) => SafeArea(
				child: Wrap(children: [
					ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Take photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
					ListTile(leading: const Icon(Icons.photo_library), title: const Text('Upload from gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
				]),
			),
		);
		if (src != null) onPick(src);
	}

	Future<void> _pickMultiProof() async {
		final list = await ImagePicker().pickMultiImage(imageQuality: 85);
		for (final x in list) {
			try {
				final b = await x.readAsBytes();
				_proofBytes.add(b);
			} catch (_) {
				_proofFiles.add(File(x.path));
			}
		}
		setState(() {});
	}

	Future<void> _captureSelfie() async {
		var status = await Permission.camera.status;
		if (!status.isGranted) {
			status = await Permission.camera.request();
		}
		if (status.isGranted) {
			await _pickSingle(ImageSource.camera, (b, f) { _selfieBytes = b; _selfieFile = f; });
		} else {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission denied. You can upload a selfie from gallery instead.')));
			}
			await _pickSingle(ImageSource.gallery, (b, f) { _selfieBytes = b; _selfieFile = f; });
		}
	}

	Future<void> _submit() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser!.uid;
			String? idUrl;
			String? selfieUrl;
			final proofUrls = <String>[];
			if (_idImageBytes != null || _idImageFile != null) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/id_${DateTime.now().millisecondsSinceEpoch}.jpg');
				if (_idImageBytes != null) { await ref.putData(_idImageBytes!, SettableMetadata(contentType: 'image/jpeg')); }
				else { await ref.putFile(_idImageFile!); }
				idUrl = await ref.getDownloadURL();
			}
			for (int i = 0; i < _proofBytes.length; i++) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/proof_b$i.jpg');
				await ref.putData(_proofBytes[i], SettableMetadata(contentType: 'image/jpeg'));
				proofUrls.add(await ref.getDownloadURL());
			}
			for (int i = 0; i < _proofFiles.length; i++) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/proof_f$i.jpg');
				await ref.putFile(_proofFiles[i]);
				proofUrls.add(await ref.getDownloadURL());
			}
			if (_selfieBytes != null || _selfieFile != null) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg');
				if (_selfieBytes != null) { await ref.putData(_selfieBytes!, SettableMetadata(contentType: 'image/jpeg')); }
				else { await ref.putFile(_selfieFile!); }
				selfieUrl = await ref.getDownloadURL();
			}

			await FirebaseFirestore.instance.collection('_onboarding').doc(uid).set({
				'uid': uid,
				'name': _name.text.trim(),
				'email': _email.text.trim(),
				'phone': _phone.text.trim(),
				'address': _address.text.trim(),
				'idType': _idType,
				'idNumber': _idNumber.text.trim(),
				'idUrl': idUrl,
				'proofUrls': proofUrls,
				'selfieUrl': selfieUrl,
				'status': 'pending',
				'createdAt': DateTime.now().toIso8601String(),
			});
			await FirebaseFirestore.instance.collection('notifications').add({
				'userId': uid,
				'title': 'KYC submitted',
				'body': 'We are reviewing your documents. You will be notified with the result shortly.',
				'route': '/notifications',
				'createdAt': DateTime.now().toIso8601String(),
				'read': false,
			});
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for review')));
				Navigator.pop(context);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
			}
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Apply as Service Provider')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
					TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
					TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
					DropdownButtonFormField<String>(value: _idType, items: const [
						DropdownMenuItem(value: 'National ID', child: Text('National ID')),
						DropdownMenuItem(value: 'Passport', child: Text('International Passport')),
						DropdownMenuItem(value: 'Driver License', child: Text('Driver’s License')),
					], onChanged: (v) => setState(() => _idType = v ?? 'National ID'), decoration: const InputDecoration(labelText: 'ID type')),
					TextField(controller: _idNumber, decoration: const InputDecoration(labelText: 'ID number')),
					ListTile(title: const Text('ID photo'), trailing: const Icon(Icons.upload_file), subtitle: Text(_idImageBytes != null || _idImageFile != null ? 'Selected' : 'Not uploaded'), onTap: () => _chooseSourceAndPick((src) => _pickSingle(src, (b,f){ _idImageBytes=b; _idImageFile=f; }))),
					ListTile(title: const Text('Proof of address/bank (multi)'), trailing: const Icon(Icons.upload_file), subtitle: Text('${_proofBytes.length + _proofFiles.length} selected'), onTap: _pickMultiProof),
					ListTile(title: const Text('Capture selfie now'), trailing: const Icon(Icons.camera_alt_outlined), subtitle: Text(_selfieBytes != null || _selfieFile != null ? 'Captured' : 'Not captured'), onTap: _captureSelfie),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Submitting...' : 'Submit')),
				],
			),
		);
	}
}

