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
	final _category = TextEditingController();
	final _price = TextEditingController();
	final _desc = TextEditingController();
	File? _image;
	bool _saving = false;

	Future<void> _pickImage() async {
		final picker = ImagePicker();
		final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (file != null) setState(() => _image = File(file.path));
	}

	Future<void> _save() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);
		try {
			String? imageUrl;
			if (_image != null) {
				final fileName = 'listings/${DateTime.now().millisecondsSinceEpoch}.jpg';
				final task = await FirebaseStorage.instance.ref(fileName).putFile(_image!);
				imageUrl = await task.ref.getDownloadURL();
			}
			await FirebaseFirestore.instance.collection('listings').add({
				'title': _title.text.trim(),
				'category': _category.text.trim(),
				'price': double.tryParse(_price.text.trim()) ?? 0,
				'description': _desc.text.trim(),
				'imageUrl': imageUrl ?? '',
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
					padding: const EdgeInsets.all(16),
					children: [
						GestureDetector(
							onTap: _pickImage,
							child: AspectRatio(
								aspectRatio: 16/9,
								child: Container(
									color: Colors.grey.shade200,
									child: _image == null ? const Icon(Icons.add_a_photo) : Image.file(_image!, fit: BoxFit.cover),
								),
							),
						),
						TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
						TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category'), validator: (v) => v!.isEmpty ? 'Required' : null),
						TextFormField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
						TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
						const SizedBox(height: 12),
						FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
					],
				),
			),
		);
	}
}