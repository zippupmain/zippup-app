import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
	File? _photoFile; // mobile/desktop
	Uint8List? _photoBytes; // web
	bool _saving = false;

	@override
	void initState() {
		super.initState();
		final u = FirebaseAuth.instance.currentUser;
		_name.text = u?.displayName ?? '';
		_phone.text = u?.phoneNumber ?? '';
		_photoUrl = u?.photoURL;
		_prefillFromFirestore();
	}

	Future<void> _prefillFromFirestore() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;
			final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
			final data = doc.data() ?? {};
			if (!mounted) return;
			if ((data['name'] ?? '').toString().trim().isNotEmpty) _name.text = data['name'];
			if ((data['phone'] ?? '').toString().trim().isNotEmpty) _phone.text = data['phone'];
			if ((data['photoUrl'] ?? '').toString().trim().isNotEmpty) setState(() => _photoUrl = data['photoUrl']);
		} catch (_) {}
	}

	Future<void> _pickPhoto() async {
		final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (f == null) return;
		if (kIsWeb) {
			final bytes = await f.readAsBytes();
			setState(() { _photoBytes = bytes; _photoFile = null; });
		} else {
			setState(() { _photoFile = File(f.path); _photoBytes = null; });
		}
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final u = FirebaseAuth.instance.currentUser;
			if (u == null) return;
			String? url = _photoUrl;
			if (_photoBytes != null || _photoFile != null) {
				final ref = FirebaseStorage.instance.ref('users/${u.uid}/profile.jpg');
				if (_photoBytes != null) {
					await ref.putData(_photoBytes!, SettableMetadata(contentType: 'image/jpeg'));
				} else if (_photoFile != null) {
					await ref.putFile(_photoFile!);
				}
				url = await ref.getDownloadURL();
			}
			final name = _name.text.trim();
			await u.updateDisplayName(name);
			// Save private profile
			await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
				'uid': u.uid,
				'name': name,
				'phone': _phone.text.trim(),
				'photoUrl': url,
				'updatedAt': FieldValue.serverTimestamp(),
			}, SetOptions(merge: true));
			// Save public profile (name + photo only)
			await FirebaseFirestore.instance.collection('public_profiles').doc(u.uid).set({
				'name': name,
				'photoUrl': url,
				'updatedAt': FieldValue.serverTimestamp(),
			});
			await u.reload();
			final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
			final fresh = (doc.data() ?? const {})['photoUrl']?.toString() ?? url;
			if (!mounted) return;
			setState(() { _photoUrl = fresh; _photoBytes = null; _photoFile = null; });
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
		Widget avatarWidget() {
			if (_photoBytes != null) {
				return ClipOval(child: Image.memory(_photoBytes!, width: 72, height: 72, fit: BoxFit.cover));
			}
			if (_photoFile != null) {
				return ClipOval(child: Image.file(_photoFile!, width: 72, height: 72, fit: BoxFit.cover));
			}
			if (_photoUrl != null && _photoUrl!.isNotEmpty) {
				return ClipOval(
					child: Image.network(_photoUrl!, width: 72, height: 72, fit: BoxFit.cover,
						errorBuilder: (context, error, stack) => const Icon(Icons.person, size: 36)),
				);
			}
			return const Icon(Icons.person, size: 36);
		}
		return Scaffold(
			appBar: AppBar(title: const Text('Profile settings')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					GestureDetector(onTap: _pickPhoto, child: CircleAvatar(radius: 36, backgroundColor: Colors.grey.shade200, child: avatarWidget())),
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