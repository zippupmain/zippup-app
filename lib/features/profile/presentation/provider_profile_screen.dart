import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class ProviderProfileScreen extends StatelessWidget {
	const ProviderProfileScreen({super.key, required this.providerId});
	final String providerId;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Provider')),
			body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				future: FirebaseFirestore.instance.collection('providers').doc(providerId).get(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final p = snap.data!.data() ?? {};
					final verified = p['verified'] == true;
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Row(children: [
								Text(p['name'] ?? 'Provider', style: Theme.of(context).textTheme.titleLarge),
								const SizedBox(width: 8),
								if (verified) const Icon(Icons.verified, color: Colors.blue, size: 18),
							]),
							const SizedBox(height: 8),
							Text('Category: ${p['category'] ?? ''}'),
							Text('Fee: ₦${(p['fee'] ?? 0).toString()}'),
							const Spacer(),
							FilledButton(onPressed: () => _openBookingSheet(context), child: const Text('Book')), 
						]),
					);
				},
			),
		);
	}

	void _openBookingSheet(BuildContext context) {
		final BuildContext parentContext = context;
		bool scheduled = false;
		DateTime? scheduledAt;
		showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			builder: (context) {
				return StatefulBuilder(builder: (context, setState) {
					return Padding(
						padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								SwitchListTile(title: const Text('Schedule booking'), value: scheduled, onChanged: (v) => setState(() => scheduled = v)),
								if (scheduled) ListTile(title: const Text('Scheduled time'), subtitle: Text(scheduledAt?.toString() ?? 'Pick time'), onTap: () async {
									final now = DateTime.now();
									final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
									if (date == null) return;
									final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
									if (time == null) return;
									setState(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
								}),
								const SizedBox(height: 12),
								FilledButton(
									onPressed: () async {
										final extra = scheduled && scheduledAt != null ? {'scheduledAt': scheduledAt!.toIso8601String()} : null;
										final orderId = await OrderService().createOrder(category: OrderCategory.hire, providerId: providerId, extra: extra);
										if (!parentContext.mounted) return;
										Navigator.pop(context);
										// Finding providers dialog
										final navigator = Navigator.of(parentContext);
										showDialog(context: parentContext, barrierDismissible: false, builder: (ctx) => const AlertDialog(title: Text('Finding providers…'), content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))));
										bool routed = false;
										late final StreamSubscription sub;
										sub = FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots().listen((snap) {
											final data = snap.data() ?? const {};
											final status = (data['status'] ?? '').toString();
											if (!routed && (status == OrderStatus.accepted.name || status == OrderStatus.assigned.name || status == OrderStatus.dispatched.name || status == OrderStatus.enroute.name)) {
												if (navigator.canPop()) navigator.pop();
												// Route to track order with GoRouter and pass orderId
												parentContext.pushNamed('trackOrder', queryParameters: {'orderId': orderId});
												routed = true;
												try { sub.cancel(); } catch (_) {}
											}
										});
										Future.delayed(const Duration(seconds: 60), () { try { sub.cancel(); } catch (_) {} if (!routed && navigator.canPop()) navigator.pop(); if (!routed && parentContext.mounted) { ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text('No provider found. Please try again.'))); } });
									},
									child: const Text('Confirm booking'),
								),
								const SizedBox(height: 16),
							],
						),
					);
				});
			},
		);
	}
}