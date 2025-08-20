import 'dart:typed_data';
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
	final List<Uint8List> _imageBytes = [];
	bool _saving = false;

	final _categories = const [
		'Electronics', 'Vehicles', 'Property', 'Home & Garden', 'Fashion', 'Jobs', 'Services', 'Baby & Kids', 'Sports', 'Hobbies', 'Free Stuff',
	];

	Future<void> _pickImage() async {
		if (_imageBytes.length >= 10) return;
		final picker = ImagePicker();
		final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
		if (x == null) return;
		final b = await x.readAsBytes();
		setState(() => _imageBytes.add(b));
	}

	Future<void> _save() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);
		try {
			final urls = <String>[];
			for (final b in _imageBytes) {
				final fileName = 'listings/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
				final task = await FirebaseStorage.instance.ref(fileName).putData(b, SettableMetadata(contentType: 'image/jpeg'));
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
					padding: const EdgeInsets.all(16),
					children: [
						TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v==null||v.trim().isEmpty)?'Required':null),
						DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'Category'), items: _categories.map((c)=>DropdownMenuItem(value:c, child: Text(c))).toList(), onChanged: (v)=> setState(()=> _category=v)),
						TextFormField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
						TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
						const SizedBox(height: 8),
						Wrap(spacing: 8, runSpacing: 8, children: [
							..._imageBytes.map((b)=>Container(width:72,height:72,decoration:BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black12), child: const Icon(Icons.image))).toList(),
							OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add), label: const Text('Add image')),
						]),
						const SizedBox(height: 12),
						FilledButton(onPressed: _saving?null:_save, child: Text(_saving? 'Saving…':'Save')),
					],
				),
			),
		);
	}
}