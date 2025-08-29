import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MenuManagementScreen extends StatefulWidget {
	const MenuManagementScreen({super.key});

	@override
	State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
	final _title = TextEditingController();
	final _price = TextEditingController();
	File? _image;
	Uint8List? _imageBytes;
	bool _saving = false;

	Stream<QuerySnapshot<Map<String, dynamic>>> _itemsStream(String vendorId) {
		return FirebaseFirestore.instance
			.collection('vendors')
			.doc(vendorId)
			.collection('menu')
			.orderBy('createdAt', descending: true)
			.snapshots();
	}

	Future<void> _delete(String id) async {
		final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
		if (vendorId.isEmpty) return;
		await FirebaseFirestore.instance.collection('vendors').doc(vendorId).collection('menu').doc(id).delete();
	}

	Future<void> _edit(BuildContext context, String id, Map<String, dynamic> item) async {
		_title.text = item['title']?.toString() ?? '';
		_price.text = ((item['price'] as num?)?.toDouble() ?? 0).toString();
		await showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			builder: (_) => Padding(
				padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
				child: Column(mainAxisSize: MainAxisSize.min, children: [
					TextField(controller: _title, decoration: const InputDecoration(labelText: 'Item title')),
					TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
					const SizedBox(height: 12),
					FilledButton(onPressed: () async {
						final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
						await FirebaseFirestore.instance.collection('vendors').doc(vendorId).collection('menu').doc(id).set({
							'title': _title.text.trim(),
							'price': double.tryParse(_price.text.trim()) ?? 0,
						}, SetOptions(merge: true));
						if (context.mounted) Navigator.pop(context);
					}, child: const Text('Save changes')),
					const SizedBox(height: 12),
				]),
			),
		);
	}

	Future<void> _pick() async {
		final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (file != null) {
			try { setState(() => _imageBytes = await file.readAsBytes()); }
			catch (_) { setState(() => _image = File(file.path)); }
		}
	}

	Future<void> _save() async {
		final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
		if (vendorId.isEmpty) return;
		setState(() => _saving = true);
		try {
			String? url;
			if (_imageBytes != null || _image != null) {
				final ref = FirebaseStorage.instance.ref('vendors/$vendorId/menu/${DateTime.now().millisecondsSinceEpoch}.jpg');
				if (_imageBytes != null) { await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg')); }
				else { await ref.putFile(_image!); }
				url = await ref.getDownloadURL();
			}
			await FirebaseFirestore.instance.collection('vendors').doc(vendorId).collection('menu').add({
				'title': _title.text.trim(),
				'price': double.tryParse(_price.text.trim()) ?? 0,
				'imageUrl': url ?? '',
				'createdAt': FieldValue.serverTimestamp(),
			});
			_title.clear();
			_price.clear();
			_image = null; _imageBytes = null;
			setState(() {});
		} finally {
			setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Menu Management')),
			floatingActionButton: FloatingActionButton.extended(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save item')),
			body: Column(
				children: [
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(
							children: [
								Expanded(child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Item title'))),
								const SizedBox(width: 8),
								SizedBox(width: 120, child: TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number)),
								const SizedBox(width: 8),
								IconButton(onPressed: _pick, icon: const Icon(Icons.image)),
							],
						),
					),
					Expanded(
						child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: _itemsStream(vendorId),
							builder: (context, snapshot) {
								if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
								final docs = snapshot.data!.docs;
								if (docs.isEmpty) return const Center(child: Text('No menu items'));
								return ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final id = docs[i].id;
										final d = docs[i].data();
										return ListTile(
											title: Text(d['title']?.toString() ?? ''),
											subtitle: Text('₦${((d['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
											trailing: Wrap(spacing: 8, children: [
												IconButton(onPressed: () => _edit(context, id, d), icon: const Icon(Icons.edit)),
												IconButton(onPressed: () => _delete(id), icon: const Icon(Icons.delete, color: Colors.redAccent)),
											]),
										);
									},
								);
							},
						),
					),
				],
			),
		);
	}
}