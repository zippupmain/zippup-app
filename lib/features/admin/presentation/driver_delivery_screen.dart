import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DriverDeliveryScreen extends StatefulWidget {
	const DriverDeliveryScreen({super.key, required this.orderId});
	final String orderId;
	@override
	State<DriverDeliveryScreen> createState() => _DriverDeliveryScreenState();
}

class _DriverDeliveryScreenState extends State<DriverDeliveryScreen> {
	final _code = TextEditingController();
	bool _saving = false;
	Future<void> _submit() async {
		setState(() => _saving = true);
		try {
			await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({'deliveryCodeEntered': _code.text.trim(), 'status': 'delivered'}, SetOptions(merge: true));
			if (mounted) Navigator.pop(context);
		} finally {
			setState(() => _saving = false);
		}
	}
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Enter delivery code')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(children: [
					TextField(controller: _code, decoration: const InputDecoration(labelText: 'Delivery code')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _submit, child: const Text('Submit')),
				]),
			),
		);
	}
}