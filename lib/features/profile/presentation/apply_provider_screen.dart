import 'dart:io';

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
	String _type = 'individual';
	File? _idDoc;
	File? _bizDoc;
	bool _saving = false;

	Future<void> _pickId() async {
		final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (f != null) setState(() => _idDoc = File(f.path));
	}
	Future<void> _pickBiz() async {
		final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (f != null) setState(() => _bizDoc = File(f.path));
	}

	Future<void> _submit() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser!.uid;
			String? idUrl;
			String? bizUrl;
			if (_idDoc != null) {
				final ref = FirebaseStorage.instance.ref('applications/$uid/id_${DateTime.now().millisecondsSinceEpoch}.jpg');
				await ref.putFile(_idDoc!);
				idUrl = await ref.getDownloadURL();
			}
			if (_bizDoc != null) {
				final ref = FirebaseStorage.instance.ref('applications/$uid/biz_${DateTime.now().millisecondsSinceEpoch}.jpg');
				await ref.putFile(_bizDoc!);
				bizUrl = await ref.getDownloadURL();
			}
			await FirebaseFirestore.instance.collection('applications').doc(uid).set({
				'name': _name.text.trim(),
				'address': _address.text.trim(),
				'category': _category,
				'type': _type,
				'title': _title.text.trim(),
				'idUrl': idUrl,
				'bizUrl': bizUrl,
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
		return Scaffold(
			appBar: AppBar(title: const Text('Apply as Provider / Vendor')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name (as on ID/passport)')),
					AddressField(controller: _address, label: 'Address'),
					DropdownButtonFormField(value: _category, items: const [
						DropdownMenuItem(value: 'transport', child: Text('Transport')),
						DropdownMenuItem(value: 'food', child: Text('Food')),
						DropdownMenuItem(value: 'groceries', child: Text('Groceries')),
						DropdownMenuItem(value: 'hire', child: Text('Hire')),
						DropdownMenuItem(value: 'marketplace', child: Text('Marketplace')),
						DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
						DropdownMenuItem(value: 'personal', child: Text('Personal')),
						DropdownMenuItem(value: 'others', child: Text('Others')),
					], onChanged: (v) => setState(() => _category = v as String), decoration: const InputDecoration(labelText: 'Service category')),
					DropdownButtonFormField(value: _type, items: const [
						DropdownMenuItem(value: 'individual', child: Text('Individual')),
						DropdownMenuItem(value: 'company', child: Text('Company')),
					], onChanged: (v) => setState(() => _type = v as String), decoration: const InputDecoration(labelText: 'Type')),
					TextField(controller: _title, decoration: const InputDecoration(labelText: 'Service title')),
					const SizedBox(height: 8),
					ListTile(title: const Text('Upload ID/Passport'), trailing: const Icon(Icons.upload_file), onTap: _pickId, subtitle: Text(_idDoc?.path.split('/').last ?? 'Not uploaded')),
					ListTile(title: const Text('Upload business document (registration/permits)'), trailing: const Icon(Icons.upload_file), onTap: _pickBiz, subtitle: Text(_bizDoc?.path.split('/').last ?? 'Not uploaded')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _submit, child: const Text('Submit application')),
				],
			),
		);
	}
}