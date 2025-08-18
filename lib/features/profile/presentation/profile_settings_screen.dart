import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends StatefulWidget {
	const ProfileSettingsScreen({super.key});
	@override
	State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
	final _name = TextEditingController();
	final _phone = TextEditingController();
	String? _photoUrl;
	File? _photoFile;
	bool _saving = false;

	@override
	void initState() {
		super.initState();
		final u = FirebaseAuth.instance.currentUser;
		_name.text = u?.displayName ?? '';
		_phone.text = u?.phoneNumber ?? '';
		_photoUrl = u?.photoURL;
	}

	Future<void> _pickPhoto() async {
		final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (x != null) setState(() => _photoFile = File(x.path));
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final u = FirebaseAuth.instance.currentUser;
			if (u == null) return;
			String? url = _photoUrl;
			if (_photoFile != null) {
				final ref = FirebaseStorage.instance.ref('users/${u.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
				await ref.putFile(_photoFile!);
				url = await ref.getDownloadURL();
				await u.updatePhotoURL(url);
			}
			final name = _name.text.trim();
			await u.updateDisplayName(name);
			await FirebaseFirestore.instance.collection('users').doc(u.uid).set({'name': name, 'phone': _phone.text.trim(), 'photoUrl': url}, SetOptions(merge: true));
			await u.reload();
			if (!mounted) return;
			setState(() { _photoUrl = url; });
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
			}
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	Future<void> _deleteAccount() async {
		final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete account'), content: const Text('This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
		if (ok != true) return;
		final u = FirebaseAuth.instance.currentUser;
		await FirebaseFirestore.instance.collection('users').doc(u!.uid).delete().catchError((_){}) ;
		await u.delete();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Profile settings')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					GestureDetector(
						onTap: _pickPhoto,
						child: CircleAvatar(radius: 36, backgroundImage: _photoFile != null ? FileImage(_photoFile!) : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?, child: (_photoUrl == null && _photoFile == null) ? const Icon(Icons.person) : null),
					),
					const SizedBox(height: 8),
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Public name')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
					const SizedBox(height: 48),
					const Divider(),
					const SizedBox(height: 8),
					const Text('Danger zone', style: TextStyle(color: Colors.red)),
					const SizedBox(height: 8),
					TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: _deleteAccount, child: const Text('Delete account')),
				],
			),
		);
	}
}