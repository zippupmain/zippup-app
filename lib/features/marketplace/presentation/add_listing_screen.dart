import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddListingScreen extends StatefulWidget {
	const AddListingScreen({super.key});

	@override
	State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
	final _formKey = GlobalKey<FormState>();
	final _title = TextEditingController();
	String? _category;
	final _price = TextEditingController();
	final _desc = TextEditingController();
	final List<File> _images = [];
	bool _saving = false;

	final _categories = const [
		'Electronics', 'Vehicles', 'Property', 'Home & Garden', 'Fashion', 'Jobs', 'Services', 'Baby & Kids', 'Sports', 'Hobbies', 'Free Stuff',
	];

	Future<void> _pickImage() async {
		if (_images.length >= 10) return;
		final picker = ImagePicker();
		final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (file != null) setState(() => _images.add(File(file.path)));
	}

	Future<void> _save() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);
		try {
			final urls = <String>[];
			for (final file in _images) {
				final fileName = 'listings/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
				final task = await FirebaseStorage.instance.ref(fileName).putFile(file);
				urls.add(await task.ref.getDownloadURL());
			}
			await FirebaseFirestore.instance.collection('listings').add({
				'title': _title.text.trim(),
				'category': _category ?? '',
				'price': double.tryParse(_price.text.trim()) ?? 0,
				'description': _desc.text.trim(),
				'imageUrls': urls,
				'sellerId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
				'createdAt': FieldValue.serverTimestamp(),
			});
			if (mounted) Navigator.of(context).pop(true);
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Add Listing')),
			body: Form(
				key: _formKey,
				child: ListView(
					padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
					children: [
						GestureDetector(
							onTap: _pickImage,
							child: SizedBox(
								height: 120,
								child: ListView.separated(
									scrollDirection: Axis.horizontal,
									itemBuilder: (context, i) => AspectRatio(
										aspectRatio: 1,
										child: Container(
											color: Colors.grey.shade200,
											child: i < _images.length ? Image.file(_images[i], fit: BoxFit.cover) : const Icon(Icons.add_a_photo),
										),
									),
									separatorBuilder: (_, __) => const SizedBox(width: 8),
									itemCount: _images.length < 10 ? _images.length + 1 : 10,
								),
							),
						),
						TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
						DropdownButtonFormField<String>(
							value: _category,
							items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
							decoration: const InputDecoration(labelText: 'Category'),
							onChanged: (v) => setState(() => _category = v),
							validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
						),
						TextFormField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
						TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
					],
				),
			),
			bottomSheet: SafeArea(
				child: Container(
					color: Theme.of(context).scaffoldBackgroundColor,
					padding: const EdgeInsets.all(16),
					child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
				),
			),
		);
	}
}