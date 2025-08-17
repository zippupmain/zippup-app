import 'package:flutter/material.dart';

class PersonalScreen extends StatelessWidget {
	const PersonalScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = const [
			('Makeup', Icons.brush),
			('Hair', Icons.face_3),
			('Nails', Icons.back_hand),
			('Pedicure', Icons.spa),
			('Massage', Icons.spa_outlined),
			('Barbing', Icons.content_cut),
			('Hair styling', Icons.face)
		];
		return Scaffold(
			appBar: AppBar(title: const Text('Personal Services'), backgroundColor: Colors.white, foregroundColor: Colors.black),
			backgroundColor: Colors.white,
			body: GridView.builder(
				padding: const EdgeInsets.all(16),
				gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2),
				itemCount: items.length,
				itemBuilder: (context, i) {
					final (label, icon) = items[i];
					return Container(
						decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
						child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.black), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.black))]),
					);
				},
			),
		);
	}
}