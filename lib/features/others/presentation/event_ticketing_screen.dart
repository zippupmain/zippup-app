import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EventTicketingScreen extends StatefulWidget {
	const EventTicketingScreen({super.key});

	@override
	State<EventTicketingScreen> createState() => _EventTicketingScreenState();
}

class _EventTicketingScreenState extends State<EventTicketingScreen> {
	String _filter = 'all';
	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🎫 Event Tickets'),
				backgroundColor: Colors.purple.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
				actions: [
					IconButton(
						onPressed: () => context.push('/events/create'),
						icon: const Icon(Icons.add_circle_outline, color: Colors.black),
						tooltip: 'Create Event',
					),
				],
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
					),
				),
				child: Column(
					children: [
						// Search bar
						Container(
							margin: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(12),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.1),
										blurRadius: 8,
										offset: const Offset(0, 2),
									),
								],
							),
							child: TextField(
								controller: _searchController,
								style: const TextStyle(color: Colors.black),
								onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
								decoration: const InputDecoration(
									hintText: '🔍 Search events, concerts, shows...',
									hintStyle: TextStyle(color: Colors.black54),
									prefixIcon: Icon(Icons.search, color: Colors.black54),
									border: InputBorder.none,
									contentPadding: EdgeInsets.all(16),
								),
							),
						),

						// Filter chips
						SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							padding: const EdgeInsets.symmetric(horizontal: 16),
							child: Row(
								children: [
									FilterChip(
										label: const Text('All Events', style: TextStyle(color: Colors.black)),
										selected: _filter == 'all',
										onSelected: (selected) => setState(() => _filter = 'all'),
									),
									const SizedBox(width: 8),
									FilterChip(
										label: const Text('Concerts', style: TextStyle(color: Colors.black)),
										selected: _filter == 'concert',
										onSelected: (selected) => setState(() => _filter = 'concert'),
									),
									const SizedBox(width: 8),
									FilterChip(
										label: const Text('Sports', style: TextStyle(color: Colors.black)),
										selected: _filter == 'sports',
										onSelected: (selected) => setState(() => _filter = 'sports'),
									),
									const SizedBox(width: 8),
									FilterChip(
										label: const Text('Theater', style: TextStyle(color: Colors.black)),
										selected: _filter == 'theater',
										onSelected: (selected) => setState(() => _filter = 'theater'),
									),
									const SizedBox(width: 8),
									FilterChip(
										label: const Text('Conference', style: TextStyle(color: Colors.black)),
										selected: _filter == 'conference',
										onSelected: (selected) => setState(() => _filter = 'conference'),
									),
								],
							),
						),

						const SizedBox(height: 16),

						// Events list
						Expanded(
							child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
								stream: FirebaseFirestore.instance
									.collection('events')
									.where('status', isEqualTo: 'active')
									.orderBy('eventDate')
									.snapshots(),
								builder: (context, snapshot) {
									if (snapshot.connectionState == ConnectionState.waiting) {
										return const Center(child: CircularProgressIndicator());
									}

									if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
										return const Center(
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(Icons.event, size: 64, color: Colors.grey),
													SizedBox(height: 16),
													Text('No events available', style: TextStyle(fontSize: 18, color: Colors.grey)),
													Text('Check back later for exciting events!', style: TextStyle(color: Colors.grey)),
												],
											),
										);
									}

									final events = snapshot.data!.docs.where((doc) {
										final data = doc.data();
										final eventName = (data['eventName'] ?? '').toString().toLowerCase();
										final category = (data['category'] ?? '').toString().toLowerCase();
										
										// Filter by category
										if (_filter != 'all' && category != _filter) return false;
										
										// Filter by search query
										if (_searchQuery.isNotEmpty && !eventName.contains(_searchQuery)) return false;
										
										// Filter out expired events
										final eventDate = DateTime.tryParse(data['eventDate'] ?? '');
										if (eventDate != null && eventDate.isBefore(DateTime.now())) return false;
										
										return true;
									}).toList();

									if (events.isEmpty) {
										return const Center(
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(Icons.search_off, size: 64, color: Colors.grey),
													SizedBox(height: 16),
													Text('No events found', style: TextStyle(fontSize: 18, color: Colors.grey)),
													Text('Try adjusting your search or filters', style: TextStyle(color: Colors.grey)),
												],
											),
										);
									}

									return ListView.builder(
										padding: const EdgeInsets.symmetric(horizontal: 16),
										itemCount: events.length,
										itemBuilder: (context, index) {
											final event = events[index];
											final data = event.data();
											return _EventCard(
												eventId: event.id,
												eventData: data,
												onTap: () => context.push('/events/${event.id}'),
											);
										},
									);
								},
							),
						),
					],
				),
			),
		);
	}
}

class _EventCard extends StatelessWidget {
	const _EventCard({
		required this.eventId,
		required this.eventData,
		required this.onTap,
	});

	final String eventId;
	final Map<String, dynamic> eventData;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		final eventName = eventData['eventName'] ?? 'Event';
		final eventDate = DateTime.tryParse(eventData['eventDate'] ?? '') ?? DateTime.now();
		final ticketPrice = (eventData['ticketPrice'] as num?)?.toDouble() ?? 0.0;
		final availableTickets = (eventData['availableTickets'] as num?)?.toInt() ?? 0;
		final totalTickets = (eventData['totalTickets'] as num?)?.toInt() ?? 0;
		final venue = eventData['venue'] ?? 'TBA';
		final category = eventData['category'] ?? 'general';
		final imageUrl = eventData['imageUrl'] ?? '';

		final categoryGradients = {
			'concert': const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
			'sports': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
			'theater': const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
			'conference': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
		};

		final gradient = categoryGradients[category] ?? const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]);

		return Container(
			margin: const EdgeInsets.only(bottom: 16),
			decoration: BoxDecoration(
				gradient: const LinearGradient(
					colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
				),
				borderRadius: BorderRadius.circular(16),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withOpacity(0.1),
						blurRadius: 8,
						offset: const Offset(0, 4),
					),
				],
			),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(16),
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Row(
						children: [
							// Event image/category indicator
							Container(
								width: 80,
								height: 80,
								decoration: BoxDecoration(
									gradient: gradient,
									borderRadius: BorderRadius.circular(12),
								),
								child: imageUrl.isNotEmpty
									? ClipRRect(
											borderRadius: BorderRadius.circular(12),
											child: Image.network(
												imageUrl,
												fit: BoxFit.cover,
												errorBuilder: (_, __, ___) => const Center(
													child: Icon(Icons.event, color: Colors.white, size: 32),
												),
											),
										)
									: const Center(
											child: Icon(Icons.event, color: Colors.white, size: 32),
										),
							),
							const SizedBox(width: 16),

							// Event details
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											eventName,
											style: const TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 16,
												color: Colors.black,
											),
										),
										const SizedBox(height: 4),
										Text(
											'📅 ${eventDate.day}/${eventDate.month}/${eventDate.year} at ${TimeOfDay.fromDateTime(eventDate).format(context)}',
											style: const TextStyle(color: Colors.black87, fontSize: 12),
										),
										const SizedBox(height: 4),
										Text(
											'📍 $venue',
											style: const TextStyle(color: Colors.black54, fontSize: 12),
										),
										const SizedBox(height: 8),
										Row(
											children: [
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
													decoration: BoxDecoration(
														color: gradient.colors.first.withOpacity(0.2),
														borderRadius: BorderRadius.circular(8),
													),
													child: Text(
														category.toUpperCase(),
														style: TextStyle(
															color: gradient.colors.first,
															fontWeight: FontWeight.bold,
															fontSize: 10,
														),
													),
												),
												const SizedBox(width: 8),
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
													decoration: BoxDecoration(
														color: availableTickets > 0 ? Colors.green.shade100 : Colors.red.shade100,
														borderRadius: BorderRadius.circular(8),
													),
													child: Text(
														'$availableTickets/$totalTickets left',
														style: TextStyle(
															color: availableTickets > 0 ? Colors.green.shade700 : Colors.red.shade700,
															fontWeight: FontWeight.bold,
															fontSize: 10,
														),
													),
												),
											],
										),
									],
								),
							),

							// Price and buy button
							Column(
								children: [
									Text(
										'₦${ticketPrice.toStringAsFixed(0)}',
										style: const TextStyle(
											fontWeight: FontWeight.bold,
											fontSize: 18,
											color: Colors.black,
										),
									),
									const SizedBox(height: 8),
									FilledButton(
										onPressed: availableTickets > 0 
											? () => _showTicketPurchaseDialog(context, eventId, eventData)
											: null,
										style: FilledButton.styleFrom(
											backgroundColor: gradient.colors.first,
											minimumSize: const Size(80, 32),
										),
										child: Text(
											availableTickets > 0 ? 'BUY' : 'SOLD OUT',
											style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
										),
									),
								],
							),
						],
					),
				),
			),
		);
	}

	void _showTicketPurchaseDialog(BuildContext context, String eventId, Map<String, dynamic> eventData) {
		int quantity = 1;
		final ticketPrice = (eventData['ticketPrice'] as num?)?.toDouble() ?? 0.0;

		showDialog(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) {
					final total = ticketPrice * quantity;
					return AlertDialog(
						title: Text('🎫 Buy Tickets'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Event: ${eventData['eventName']}'),
								const SizedBox(height: 16),
								Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										const Text('Quantity:'),
										Row(
											children: [
												IconButton(
													onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
													icon: const Icon(Icons.remove),
												),
												Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
												IconButton(
													onPressed: () => setDialogState(() => quantity++),
													icon: const Icon(Icons.add),
												),
											],
										),
									],
								),
								const SizedBox(height: 16),
								Text('Total: ₦${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
							],
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(ctx),
								child: const Text('Cancel'),
							),
							FilledButton(
								onPressed: () async {
									await _purchaseTickets(context, eventId, quantity, total);
									Navigator.pop(ctx);
								},
								child: const Text('Purchase'),
							),
						],
					);
				},
			),
		);
	}

	Future<void> _purchaseTickets(BuildContext context, String eventId, int quantity, double total) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;

			// Create ticket purchase
			final ticketRef = FirebaseFirestore.instance.collection('tickets').doc();
			await ticketRef.set({
				'userId': uid,
				'eventId': eventId,
				'quantity': quantity,
				'totalPrice': total,
				'purchaseDate': DateTime.now().toIso8601String(),
				'status': 'confirmed',
				'ticketNumbers': List.generate(quantity, (index) => '${eventId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch}-${index + 1}'),
			});

			// Update available tickets
			await FirebaseFirestore.instance.collection('events').doc(eventId).update({
				'availableTickets': FieldValue.increment(-quantity),
			});

			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('✅ $quantity ticket(s) purchased successfully!')),
				);
			}
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Purchase failed: $e')),
				);
			}
		}
	}
}