import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OthersProvidersScreen extends StatefulWidget {
	const OthersProvidersScreen({super.key, required this.serviceType, this.appointmentId});
	final String serviceType;
	final String? appointmentId;

	@override
	State<OthersProvidersScreen> createState() => _OthersProvidersScreenState();
}

class _OthersProvidersScreenState extends State<OthersProvidersScreen> {
	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';

	final Map<String, Map<String, dynamic>> _serviceConfigs = {
		'events': {
			'title': '🎉 Event Planning Providers',
			'icon': Icons.celebration,
			'color': Colors.pink,
			'services': ['Wedding Planning', 'Birthday Parties', 'Corporate Events', 'Conferences'],
		},
		'tutoring': {
			'title': '👨‍🏫 Tutoring Providers',
			'icon': Icons.school,
			'color': Colors.blue,
			'services': ['Math', 'English', 'Science', 'Languages', 'Music', 'Art'],
		},
		'education': {
			'title': '📚 Education Providers',
			'icon': Icons.menu_book,
			'color': Colors.green,
			'services': ['Online Courses', 'Workshops', 'Seminars', 'Training Programs'],
		},
		'creative': {
			'title': '🎨 Creative Service Providers',
			'icon': Icons.palette,
			'color': Colors.purple,
			'services': ['Photography', 'Graphic Design', 'Content Creation', 'Video Production'],
		},
		'business': {
			'title': '💼 Business Service Providers',
			'icon': Icons.business,
			'color': Colors.indigo,
			'services': ['Consulting', 'Legal Services', 'Accounting', 'Marketing', 'HR Services'],
		},
	};

	Future<void> _bookProvider(String providerId, Map<String, dynamic> providerData) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;

			// Create direct booking with provider
			await FirebaseFirestore.instance.collection('direct_bookings').add({
				'clientId': uid,
				'providerId': providerId,
				'serviceType': widget.serviceType,
				'providerName': providerData['name'] ?? 'Provider',
				'providerService': providerData['specialization'] ?? '',
				'appointmentId': widget.appointmentId,
				'status': 'pending_confirmation',
				'createdAt': DateTime.now().toIso8601String(),
			});

			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('✅ Booking request sent to provider!'),
						backgroundColor: Colors.green,
					)
				);
				context.pop();
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Booking failed: $e'))
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final config = _serviceConfigs[widget.serviceType] ?? _serviceConfigs['events']!;
		final serviceColor = config['color'] as Color;

		return Scaffold(
			appBar: AppBar(
				title: Text(config['title'] as String),
				backgroundColor: serviceColor.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: Column(
					children: [
						// Search bar
						Container(
							color: Colors.white,
							padding: const EdgeInsets.all(16),
							child: TextField(
								controller: _searchController,
								style: const TextStyle(color: Colors.black),
								decoration: InputDecoration(
									labelText: 'Search providers...',
									labelStyle: const TextStyle(color: Colors.black),
									hintText: 'Name, specialization, or location...',
									hintStyle: const TextStyle(color: Colors.black38),
									prefixIcon: Icon(Icons.search, color: serviceColor),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(color: serviceColor),
									),
									focusedBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(color: serviceColor.shade600, width: 2),
									),
									filled: true,
									fillColor: serviceColor.shade50,
								),
								onChanged: (value) {
									setState(() => _searchQuery = value.toLowerCase());
								},
							),
						),

						// Service filters
						Container(
							color: Colors.white,
							padding: const EdgeInsets.symmetric(horizontal: 16),
							child: SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: (config['services'] as List<String>).map((service) => Padding(
										padding: const EdgeInsets.only(right: 8),
										child: FilterChip(
											label: Text(service, style: const TextStyle(color: Colors.black, fontSize: 12)),
											onSelected: (selected) {
												if (selected) {
													_searchController.text = service;
													setState(() => _searchQuery = service.toLowerCase());
												}
											},
											backgroundColor: Colors.white,
											selectedColor: serviceColor.shade100,
										),
									)).toList(),
								),
							),
						),

						const Divider(height: 1),

						// Providers list
						Expanded(
							child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
								stream: FirebaseFirestore.instance
									.collection('providers')
									.where('category', isEqualTo: 'others')
									.where('subcategory', isEqualTo: widget.serviceType)
									.snapshots(),
								builder: (context, snapshot) {
									if (snapshot.connectionState == ConnectionState.waiting) {
										return const Center(child: CircularProgressIndicator());
									}

									if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
										return Center(
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(config['icon'] as IconData, size: 64, color: Colors.grey.shade400),
													const SizedBox(height: 16),
													Text(
														'No ${widget.serviceType} providers found',
														style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
													),
													const SizedBox(height: 8),
													Text(
														'Try adjusting your search or check back later',
														style: TextStyle(color: Colors.grey.shade500),
													),
												],
											),
										);
									}

									final docs = snapshot.data!.docs.where((doc) {
										if (_searchQuery.isEmpty) return true;
										final data = doc.data();
										final name = (data['name'] ?? '').toString().toLowerCase();
										final specialization = (data['specialization'] ?? '').toString().toLowerCase();
										final description = (data['description'] ?? '').toString().toLowerCase();
										return name.contains(_searchQuery) || 
											   specialization.contains(_searchQuery) || 
											   description.contains(_searchQuery);
									}).toList();

									if (docs.isEmpty) {
										return Center(
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
													const SizedBox(height: 16),
													Text(
														'No providers match "$_searchQuery"',
														style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
													),
													const SizedBox(height: 8),
													const Text(
														'Try a different search term',
														style: TextStyle(color: Colors.grey),
													),
												],
											),
										);
									}

									return ListView.separated(
										padding: const EdgeInsets.all(16),
										itemCount: docs.length,
										separatorBuilder: (context, index) => const SizedBox(height: 12),
										itemBuilder: (context, index) {
											final data = docs[index].data();
											final providerId = docs[index].id;
											final name = (data['name'] ?? 'Provider').toString();
											final specialization = (data['specialization'] ?? '').toString();
											final description = (data['description'] ?? '').toString();
											final rating = (data['rating'] ?? 0.0).toDouble();
											final hourlyRate = (data['hourlyRate'] ?? 0.0).toDouble();
											final photo = (data['photoUrl'] ?? '').toString();
											final experience = (data['experience'] ?? 0).toString();

											return Card(
												elevation: 4,
												child: Padding(
													padding: const EdgeInsets.all(16),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															// Provider header
															Row(
																children: [
																	CircleAvatar(
																		radius: 30,
																		backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
																		child: photo.isEmpty ? Icon(config['icon'] as IconData, color: serviceColor) : null,
																	),
																	const SizedBox(width: 16),
																	Expanded(
																		child: Column(
																			crossAxisAlignment: CrossAxisAlignment.start,
																			children: [
																				Text(
																					name,
																					style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
																				),
																				if (specialization.isNotEmpty) Text(
																					specialization,
																					style: TextStyle(color: serviceColor.shade700, fontWeight: FontWeight.w600),
																				),
																				Row(
																					children: [
																						Icon(Icons.star, color: Colors.amber, size: 16),
																						const SizedBox(width: 4),
																						Text('$rating', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
																						const SizedBox(width: 12),
																						Icon(Icons.work, color: Colors.grey, size: 16),
																						const SizedBox(width: 4),
																						Text('${experience}yr exp', style: const TextStyle(color: Colors.black)),
																					],
																				),
																			],
																		),
																	),
																],
															),

															const SizedBox(height: 12),

															// Description
															if (description.isNotEmpty) Container(
																padding: const EdgeInsets.all(12),
																decoration: BoxDecoration(
																	color: serviceColor.shade50,
																	borderRadius: BorderRadius.circular(8),
																),
																child: Text(
																	description,
																	style: const TextStyle(color: Colors.black87),
																),
															),

															const SizedBox(height: 12),

															// Pricing and action
															Row(
																children: [
																	Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Text(
																				'₦${hourlyRate.toStringAsFixed(0)}/hour',
																				style: TextStyle(
																					fontSize: 18,
																					fontWeight: FontWeight.bold,
																					color: serviceColor.shade700,
																				),
																			),
																			const Text(
																				'Starting rate',
																				style: TextStyle(color: Colors.grey, fontSize: 12),
																			),
																		],
																	),
																	const Spacer(),
																	FilledButton.icon(
																		onPressed: () => _bookProvider(providerId, data),
																		icon: const Icon(Icons.calendar_today),
																		label: const Text('Book Now'),
																		style: FilledButton.styleFrom(
																			backgroundColor: serviceColor.shade600,
																		),
																	),
																],
															),
														],
													),
												),
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