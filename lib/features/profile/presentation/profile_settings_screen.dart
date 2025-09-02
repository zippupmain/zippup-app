import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class ProfileSettingsScreen extends StatefulWidget {
	const ProfileSettingsScreen({super.key});
	@override
	State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
	final _name = TextEditingController();
	final _phone = TextEditingController();
	final _email = TextEditingController();
	String? _photoUrl;
	Uint8List? _photoBytes; // web & mobile compatible
	bool _saving = false;

	@override
	void initState() {
		super.initState();
		final u = FirebaseAuth.instance.currentUser;
		_name.text = u?.displayName ?? '';
		_phone.text = u?.phoneNumber ?? '';
		_email.text = u?.email ?? '';
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
			if ((data['email'] ?? '').toString().trim().isNotEmpty) _email.text = data['email'];
		} catch (_) {}
	}

	Future<void> _pickPhoto() async {
		final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (f == null) return;
		final bytes = await f.readAsBytes();
		setState(() { _photoBytes = bytes; });
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final u = FirebaseAuth.instance.currentUser;
			if (u == null) return;
			String? url = _photoUrl;
			if (_photoBytes != null) {
				// TEST MODE: Use simple placeholder URL to avoid Firestore size limits
				url = 'placeholder://profile-${u.uid}-${DateTime.now().millisecondsSinceEpoch}';
				print('✅ Profile picture (test mode): placeholder URL created');
				
				// Keep the image bytes in local state for display
				setState(() => _photoUrl = url);
			}
			final name = _name.text.trim();
			final email = _email.text.trim();
			await u.updateDisplayName(name);
			if (email.isNotEmpty && email != (u.email ?? '')) {
				try { await u.verifyBeforeUpdateEmail(email); } catch (_) {}
			}
			// Save private profile
			await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
				'uid': u.uid,
				'name': name,
				'phone': _phone.text.trim(),
				'email': email,
				'photoUrl': url,
				'updatedAt': FieldValue.serverTimestamp(),
			}, SetOptions(merge: true));
			// Save public profile (name + photo only)
			await FirebaseFirestore.instance.collection('public_profiles').doc(u.uid).set({
				'name': name,
				'photoUrl': url,
				'updatedAt': FieldValue.serverTimestamp(),
			});
			// Don't reload from Firestore in test mode, keep local state
			if (!mounted) return;
			// Keep _photoBytes so image stays visible
			setState(() => _photoUrl = url);
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
					TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email address')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
					const SizedBox(height: 24),
					
					// Notification test button
					OutlinedButton.icon(
						onPressed: () => context.push('/notification-test'),
						icon: const Icon(Icons.volume_up, color: Colors.orange),
						label: const Text('🔔 Test Notification Sounds', style: TextStyle(color: Colors.orange)),
						style: OutlinedButton.styleFrom(
							side: const BorderSide(color: Colors.orange),
							padding: const EdgeInsets.symmetric(vertical: 12),
						),
					),
					
					const SizedBox(height: 24),
					const Divider(),
				],
			),
		);
	}
}