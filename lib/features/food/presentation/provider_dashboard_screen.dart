import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/order.dart' as models;
import 'package:zippup/features/food/providers/order_service.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class ProviderDashboardScreen extends StatefulWidget {
	const ProviderDashboardScreen({super.key});

	@override
	State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
	late final OrderService _service;
	String _providerId = '';
	Stream<List<models.Order>>? _pendingStream;
	bool _kitchenOpen = true;
	bool _online = true;
	bool _hideNewWhenClosed = true;
	models.OrderStatus? _filterStatus;

	Future<void> _dispatchNextReady() async {
		try {
			final uid = _providerId;
			final q = await FirebaseFirestore.instance
				.collection('orders')
				.where('providerId', isEqualTo: uid)
				.where('status', isEqualTo: models.OrderStatus.dispatched.name)
				.limit(1)
				.get();
			if (q.docs.isEmpty) {
				if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No orders to dispatch')));
				return;
			}
			await q.docs.first.reference.set({'status': 'dispatched'}, SetOptions(merge: true));
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatching to courier…')));
		} catch (_) {}
	}

	void _showManualDeliveryAssignment() {
		final TextEditingController courierIdController = TextEditingController();
		final TextEditingController orderIdController = TextEditingController();

		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('🚚 Manual Delivery Assignment'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Text('Assign a specific courier to an order by entering their User ID:'),
						const SizedBox(height: 16),
						TextField(
							controller: orderIdController,
							decoration: const InputDecoration(
								labelText: 'Order ID',
								hintText: 'Enter order ID to assign',
								prefixIcon: Icon(Icons.receipt),
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 12),
						TextField(
							controller: courierIdController,
							decoration: const InputDecoration(
								labelText: 'Courier User ID',
								hintText: 'Enter courier\'s user ID',
								prefixIcon: Icon(Icons.person),
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 8),
						const Text(
							'💡 Tip: You can find courier User IDs in their profile or ask them directly',
							style: TextStyle(fontSize: 12, color: Colors.grey),
						),
					],
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(context),
						child: const Text('Cancel'),
					),
					ElevatedButton(
						onPressed: () => _assignCourierToOrder(
							orderIdController.text.trim(),
							courierIdController.text.trim(),
							context,
						),
						child: const Text('Assign'),
					),
				],
			),
		);
	}

	Future<void> _assignCourierToOrder(String orderId, String courierId, BuildContext dialogContext) async {
		if (orderId.isEmpty || courierId.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('❌ Please enter both Order ID and Courier ID')),
			);
			return;
		}

		try {
			// Verify order exists and belongs to this provider
			final orderDoc = await FirebaseFirestore.instance
				.collection('orders')
				.doc(orderId)
				.get();

			if (!orderDoc.exists) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('❌ Order not found')),
				);
				return;
			}

			final orderData = orderDoc.data()!;
			if (orderData['providerId'] != _providerId) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('❌ Order does not belong to your business')),
				);
				return;
			}

			// Verify courier exists and is a delivery provider
			final courierDoc = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: courierId)
				.where('service', isEqualTo: 'delivery')
				.limit(1)
				.get();

			if (courierDoc.docs.isEmpty) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('❌ Courier not found or not a delivery provider')),
				);
				return;
			}

			// Assign courier to order
			await FirebaseFirestore.instance
				.collection('orders')
				.doc(orderId)
				.update({
				'assignedCourierId': courierId,
				'status': models.OrderStatus.assigned.name,
				'assignedAt': FieldValue.serverTimestamp(),
				'assignedBy': 'manual',
			});

			// Create notification for courier
			await FirebaseFirestore.instance
				.collection('notifications')
				.add({
				'userId': courierId,
				'title': '📦 New Delivery Assignment',
				'message': 'You have been manually assigned to deliver Order $orderId',
				'type': 'delivery_assignment',
				'orderId': orderId,
				'createdAt': FieldValue.serverTimestamp(),
				'read': false,
			});

			Navigator.pop(dialogContext);
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('✅ Courier assigned successfully!'),
						backgroundColor: Colors.green,
					),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('❌ Error assigning courier: $e')),
				);
			}
		}
	}

	@override
	void initState() {
		super.initState();
		_service = OrderService();
		_providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
		_initializeProvider();
		_pendingStream = FirebaseFirestore.instance
			.collection('orders')
			.where('providerId', isEqualTo: _providerId)
			.where('status', isEqualTo: models.OrderStatus.pending.name)
			.snapshots()
			.map((snap) => snap.docs.map((d) => models.Order.fromJson(d.id, d.data())).toList());
	}

	Future<void> _initializeProvider() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;

			// Set provider to online by default
			final providerProfile = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', whereIn: ['food', 'grocery'])
				.limit(1)
				.get();

			if (providerProfile.docs.isNotEmpty) {
				await FirebaseFirestore.instance
					.collection('provider_profiles')
					.doc(providerProfile.docs.first.id)
					.update({'availabilityOnline': true});
			}
		} catch (e) {
			// Ignore errors during initialization
		}
	}

	Stream<List<models.Order>> _ordersStream(String providerId) {
		Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('orders').where('providerId', isEqualTo: providerId);
		// Optional: filter by status when kitchen is open (show actionable first)
		return q.orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((d) => models.Order.fromJson(d.id, d.data())).toList());
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Food Provider Dashboard'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: Stack(
				children: [
					const ProviderHeader(service: 'food'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(children: [
							Expanded(child: SwitchListTile(title: const Text('Kitchen open'), value: _kitchenOpen, onChanged: (v) async {
								setState(() => _kitchenOpen = v);
								try {
									await FirebaseFirestore.instance.collection('vendors').doc(_providerId).set({'kitchenOpen': v}, SetOptions(merge: true));
								} catch (_) {}
							})),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/vendor/menu?vendorId=${_providerId}'), icon: const Icon(Icons.menu_book), label: const Text('Manage menu')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/menu/manage'), icon: const Icon(Icons.edit_note), label: const Text('Add/Edit items')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/categories/manage'), icon: const Icon(Icons.category), label: const Text('Food categories')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/grocery/seller-categories'), icon: const Icon(Icons.shopping_basket), label: const Text('Grocery categories')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/kitchen/hours'), icon: const Icon(Icons.schedule), label: const Text('Kitchen hours')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: _dispatchNextReady, icon: const Icon(Icons.delivery_dining), label: const Text('Auto dispatch')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: _showManualDeliveryAssignment, icon: const Icon(Icons.person_add), label: const Text('Assign courier')),
						]),
					),
					StreamBuilder<List<models.Order>>(
						stream: _ordersStream(_providerId),
						builder: (context, snapshot) {
							if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
							List<models.Order> orders = snapshot.data!;
							final statuses = [
								models.OrderStatus.pending,
								models.OrderStatus.preparing,
								models.OrderStatus.dispatched,
								models.OrderStatus.assigned,
								models.OrderStatus.enroute,
								models.OrderStatus.arrived,
								models.OrderStatus.delivered,
							];
							if (_filterStatus != null) {
								orders = orders.where((o) => o.status == _filterStatus).toList();
							}
							return Column(children: [
								SingleChildScrollView(
									scrollDirection: Axis.horizontal,
									child: Row(children: [
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
											child: FilterChip(
												label: const Text('📋 All History'),
												selected: _filterStatus == null,
												onSelected: (_) { setState(() => _filterStatus = null); },
											),
										),
										...statuses.map((s) => Padding(
											padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
											child: FilterChip(
												label: Text(s.name),
												selected: _filterStatus == s,
												onSelected: (_) { setState(() => _filterStatus = s); },
											),
										)),
										const SizedBox(width: 8),
										if (!_kitchenOpen)
											FilterChip(
												label: const Text('Hide new when closed'),
												selected: _hideNewWhenClosed,
												onSelected: (_) { setState(() => _hideNewWhenClosed = !_hideNewWhenClosed); },
											),
									]),
								),
								Expanded(
									child: orders.isEmpty
										? const Center(child: Text('No orders yet'))
										: ListView.separated(
											itemCount: orders.length,
											separatorBuilder: (_, __) => const Divider(height: 1),
											itemBuilder: (context, i) {
												final o = orders[i];
												if (!_kitchenOpen && _hideNewWhenClosed && o.status == models.OrderStatus.pending) {
													return const SizedBox.shrink();
												}
												return ListTile(
													title: Text('Order ${o.id.substring(0, 6)} • ${o.category.name}'),
													subtitle: Text('Status: ${o.status.name}'),
													trailing: Wrap(spacing: 8, children: _actionsFor(context, o, _service)),
												);
											},
										),
								),
							]);
						},
					),
					// Listener overlay
					StreamBuilder<List<models.Order>>(
						stream: _pendingStream,
						builder: (context, snapshot) {
							if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
							final pending = snapshot.data!;
							final latest = pending.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New order request'),
										content: Text('Order ${latest.id.substring(0, 6)} • ${latest.category.name}'),
										actions: [
											TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
											FilledButton(onPressed: () { _service.updateStatus(orderId: latest.id, status: models.OrderStatus.accepted); Navigator.pop(context); }, child: const Text('Accept')),
											TextButton(onPressed: () { _service.updateStatus(orderId: latest.id, status: models.OrderStatus.rejected); Navigator.pop(context); }, child: const Text('Decline')),
										],
									),
								);
							});
							return const SizedBox.shrink();
						},
					),
				],
			),
		);
	}

	List<Widget> _actionsFor(BuildContext context, models.Order o, OrderService service) {
		switch (o.category) {
			case models.OrderCategory.food:
				return _foodActions(context, o, service);
			case models.OrderCategory.groceries:
				return _groceryActions(context, o, service);
			default:
				return _commonActions(o, service);
		}
	}

	List<Widget> _foodActions(BuildContext context, models.Order o, OrderService s) {
		return [
			if (o.status == models.OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.preparing), child: const Text('Prepare')),
			if (o.status == models.OrderStatus.preparing)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.dispatched), child: const Text('Dispatch')),
			if (o.status == models.OrderStatus.dispatched)
				TextButton(onPressed: () => _promptAssignCourier(context, o, s), child: const Text('Assign courier')),
			if (o.status == models.OrderStatus.assigned)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.enroute), child: const Text('Enroute')),
			if (o.status == models.OrderStatus.enroute)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.arrived), child: const Text('Arrived')),
			if (o.status == models.OrderStatus.arrived)
				FilledButton(onPressed: () => _promptAndComplete(context, o, s), child: const Text('Enter code')),
		];
	}

	List<Widget> _groceryActions(BuildContext context, models.Order o, OrderService s) {
		return [
			if (o.status == models.OrderStatus.preparing)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.sorting), child: const Text('Sorting')),
			if (o.status == models.OrderStatus.sorting)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.dispatched), child: const Text('Dispatch')),
			..._foodActions(context, o, s),
		];
	}

	List<Widget> _commonActions(models.Order o, OrderService s) {
		return [
			if (o.status == models.OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.accepted), child: const Text('Accept')),
			if (o.status == models.OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.rejected), child: const Text('Reject')),
		];
	}

	Future<void> _promptAndComplete(BuildContext context, models.Order o, OrderService s) async {
		final controller = TextEditingController();
		final code = await showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Enter delivery code'),
				content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '6-digit code')),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Submit')),
				],
			),
		);
		if (code == null) return;
		if (o.deliveryCode != null && o.deliveryCode != code) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code')));
			}
			return;
		}
		await s.updateStatus(orderId: o.id, status: models.OrderStatus.delivered, extra: {'deliveryCodeEntered': code});
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery completed')));
		}
	}

	Future<void> _promptAssignCourier(BuildContext context, models.Order o, OrderService s) async {
		final controller = TextEditingController();
		final courier = await showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Assign courier'),
				content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Courier UID or phone')), 
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Assign')),
				],
			),
		);
		if (courier == null || courier.isEmpty) return;
		await s.updateStatus(orderId: o.id, status: models.OrderStatus.assigned, deliveryId: courier);
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Courier assigned')));
		}
	}
}