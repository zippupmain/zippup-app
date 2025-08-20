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
	final List<Uint8List> _proofBytes = [];
	Uint8List? _selfieBytes;
	bool _saving = false;

	Future<void> _pickSingle(ImageSource source, void Function(Uint8List?) setter) async {
		final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
		if (x == null) return;
		final b = await x.readAsBytes();
		setter(b);
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
			_proofBytes.add(await x.readAsBytes());
		}
		setState(() {});
	}

	Future<void> _captureSelfie() async {
		var status = await Permission.camera.status;
		if (!status.isGranted) {
			status = await Permission.camera.request();
		}
		if (status.isGranted) {
			await _pickSingle(ImageSource.camera, (b) { _selfieBytes = b; });
		} else {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission denied. You can upload a selfie from gallery instead.')));
			}
			await _pickSingle(ImageSource.gallery, (b) { _selfieBytes = b; });
		}
	}

	Future<void> _submit() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser!.uid;
			String? idUrl;
			String? selfieUrl;
			final proofUrls = <String>[];
			if (_idImageBytes != null) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/id_${DateTime.now().millisecondsSinceEpoch}.jpg');
				await ref.putData(_idImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
				idUrl = await ref.getDownloadURL();
			}
			for (int i = 0; i < _proofBytes.length; i++) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/proof_b$i.jpg');
				await ref.putData(_proofBytes[i], SettableMetadata(contentType: 'image/jpeg'));
				proofUrls.add(await ref.getDownloadURL());
			}
			if (_selfieBytes != null) {
				final ref = FirebaseStorage.instance.ref('onboarding/$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg');
				await ref.putData(_selfieBytes!, SettableMetadata(contentType: 'image/jpeg'));
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
				'idDocUrl': idUrl,
				'selfieUrl': selfieUrl,
				'proofUrls': proofUrls,
				'createdAt': FieldValue.serverTimestamp(),
				'status': 'pending',
			});

			if (mounted) Navigator.of(context).pop(true);
		} catch (e) {
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('KYC Onboarding')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
					TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
					TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
					DropdownButtonFormField<String>(value: _idType, items: const ['National ID','International Passport','Driver\'s License'].map((e)=>DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v)=> setState(()=> _idType=v??_idType)),
					TextField(controller: _idNumber, decoration: const InputDecoration(labelText: 'ID number')),
					Row(children: [
						OutlinedButton.icon(onPressed: () => _chooseSourceAndPick((s)=> _pickSingle(s, (b){ _idImageBytes=b; })), icon: const Icon(Icons.image), label: const Text('Pick ID document')),
					]),
					Row(children: [
						OutlinedButton.icon(onPressed: _pickMultiProof, icon: const Icon(Icons.file_copy), label: const Text('Add proof docs')),
					]),
					Row(children: [
						OutlinedButton.icon(onPressed: _captureSelfie, icon: const Icon(Icons.camera_alt), label: const Text('Capture selfie')),
					]),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving?null:_submit, child: Text(_saving? 'Submitting…' : 'Submit')),
				],
			),
		);
	}
}

