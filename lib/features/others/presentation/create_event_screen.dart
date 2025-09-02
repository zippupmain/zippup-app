import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/widgets/address_field.dart';

class CreateEventScreen extends StatefulWidget {
	const CreateEventScreen({super.key});

	@override
	State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
	final TextEditingController _eventNameController = TextEditingController();
	final TextEditingController _descriptionController = TextEditingController();
	final TextEditingController _venueController = TextEditingController();
	final TextEditingController _ticketPriceController = TextEditingController();
	final TextEditingController _totalTicketsController = TextEditingController();
	DateTime? _eventDate;
	TimeOfDay? _eventTime;
	String _category = 'concert';
	bool _isCreating = false;
	List<String> _ticketImages = []; // URLs of uploaded ticket images
	bool _uploadingImages = false;

	Future<void> _uploadTicketImages() async {
		setState(() => _uploadingImages = true);
		
		try {
			// Simulate multiple image upload (in real implementation, use image_picker)
			// For now, add placeholder URLs
			final newImages = <String>[
				'https://via.placeholder.com/300x200/4CAF50/FFFFFF?text=Ticket+1',
				'https://via.placeholder.com/300x200/2196F3/FFFFFF?text=Ticket+2',
			];
			
			setState(() {
				_ticketImages.addAll(newImages);
				if (_ticketImages.length > 15) {
					_ticketImages = _ticketImages.take(15).toList();
				}
			});
			
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('✅ Added ${newImages.length} ticket images')),
			);
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('❌ Error uploading images: $e')),
			);
		} finally {
			setState(() => _uploadingImages = false);
		}
	}

	final Map<String, String> _categories = {
		'concert': '🎵 Concert',
		'sports': '⚽ Sports',
		'theater': '🎭 Theater',
		'conference': '💼 Conference',
		'workshop': '🛠️ Workshop',
		'festival': '🎪 Festival',
	};

	Future<void> _createEvent() async {
		final eventName = _eventNameController.text.trim();
		final description = _descriptionController.text.trim();
		final venue = _venueController.text.trim();
		final ticketPrice = double.tryParse(_ticketPriceController.text.trim()) ?? 0;
		final totalTickets = int.tryParse(_totalTicketsController.text.trim()) ?? 0;

		if (eventName.isEmpty || venue.isEmpty || _eventDate == null || _eventTime == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please fill all required fields'))
			);
			return;
		}

		if (totalTickets <= 0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter valid number of tickets'))
			);
			return;
		}

		setState(() => _isCreating = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to create events'))
				);
				return;
			}

			final eventDateTime = DateTime(
				_eventDate!.year,
				_eventDate!.month,
				_eventDate!.day,
				_eventTime!.hour,
				_eventTime!.minute,
			);

			// Create event with ticket images
			final eventRef = FirebaseFirestore.instance.collection('events').doc();
			await eventRef.set({
				'organizerId': uid,
				'eventName': eventName,
				'description': description,
				'category': _category,
				'venue': venue,
				'eventDate': eventDateTime.toIso8601String(),
				'ticketPrice': ticketPrice,
				'totalTickets': totalTickets,
				'availableTickets': totalTickets,
				'soldTickets': 0,
				'status': 'active',
				'createdAt': DateTime.now().toIso8601String(),
				'currency': 'NGN',
				'ticketImages': _ticketImages, // Ticket design images
				'referencePrefix': eventRef.id.substring(0, 6).toUpperCase(), // Event reference prefix
			});

			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('✅ Event created successfully!'))
				);
				context.pop();
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed to create event: $e'))
				);
			}
		} finally {
			setState(() => _isCreating = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🎪 Create Event'),
				backgroundColor: Colors.purple.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white, // White background for text visibility
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Colors.white, Color(0xFFFAFAFA)],
					),
				),
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Event details
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _eventNameController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Event Name *',
													labelStyle: TextStyle(color: Colors.black87),
													border: OutlineInputBorder(),
													filled: true,
													fillColor: Colors.white,
												),
											),
											const SizedBox(height: 12),
											const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
											const SizedBox(height: 8),
											Wrap(
												spacing: 8,
												children: _categories.entries.map((entry) {
													final isSelected = entry.key == _category;
													return FilterChip(
														label: Text(entry.value, style: const TextStyle(color: Colors.black)),
														selected: isSelected,
														onSelected: (selected) {
															setState(() => _category = entry.key);
														},
														selectedColor: Colors.purple.shade100,
													);
												}).toList(),
											),
											const SizedBox(height: 12),
											TextField(
												controller: _descriptionController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Event Description',
													labelStyle: TextStyle(color: Colors.black87),
													border: OutlineInputBorder(),
													filled: true,
													fillColor: Colors.white,
												),
												maxLines: 3,
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Date, time, and venue
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Schedule & Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () async {
																final date = await showDatePicker(
																	context: context,
																	firstDate: DateTime.now(),
																	lastDate: DateTime.now().add(const Duration(days: 365)),
																	initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 7)),
																);
																if (date != null) {
																	setState(() => _eventDate = date);
																}
															},
															icon: const Icon(Icons.calendar_today, color: Colors.black),
															label: Text(
																_eventDate == null 
																	? 'Select Date *' 
																	: '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
																style: const TextStyle(color: Colors.black),
															),
														),
													),
													const SizedBox(width: 12),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () async {
																final time = await showTimePicker(
																	context: context,
																	initialTime: _eventTime ?? const TimeOfDay(hour: 19, minute: 0),
																);
																if (time != null) {
																	setState(() => _eventTime = time);
																}
															},
															icon: const Icon(Icons.access_time, color: Colors.black),
															label: Text(
																_eventTime == null 
																	? 'Select Time *' 
																	: _eventTime!.format(context),
																style: const TextStyle(color: Colors.black),
															),
														),
													),
												],
											),
											const SizedBox(height: 12),
											AddressField(
												controller: _venueController,
												label: 'Event Venue *',
												hint: 'Enter venue address or location',
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Ticketing details
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Ticketing Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: TextField(
															controller: _ticketPriceController,
															style: const TextStyle(color: Colors.black),
															keyboardType: TextInputType.number,
															decoration: const InputDecoration(
																labelText: 'Ticket Price (NGN) *',
																labelStyle: TextStyle(color: Colors.black87),
																border: OutlineInputBorder(),
																filled: true,
																fillColor: Colors.white,
																prefixText: '₦ ',
															),
														),
													),
													const SizedBox(width: 12),
													Expanded(
														child: TextField(
															controller: _totalTicketsController,
															style: const TextStyle(color: Colors.black),
															keyboardType: TextInputType.number,
															decoration: const InputDecoration(
																labelText: 'Total Tickets *',
																labelStyle: TextStyle(color: Colors.black87),
																border: OutlineInputBorder(),
																filled: true,
																fillColor: Colors.white,
															),
														),
													),
												],
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Ticket images section
							Card(
								color: Colors.white,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('🎫 Ticket Design', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 8),
											const Text('Upload ticket images that buyers will receive (max 15 images)', style: TextStyle(color: Colors.black87)),
											const SizedBox(height: 12),
											
											// Image upload area
											Container(
												width: double.infinity,
												height: 120,
												decoration: BoxDecoration(
													border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
													borderRadius: BorderRadius.circular(8),
													color: Colors.grey.shade50,
												),
												child: _ticketImages.isEmpty
													? Column(
														mainAxisAlignment: MainAxisAlignment.center,
														children: [
															Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
															const SizedBox(height: 8),
															Text('Tap to upload ticket images', style: TextStyle(color: Colors.grey.shade600)),
															const Text('(Multiple selection supported)', style: TextStyle(color: Colors.grey, fontSize: 12)),
														],
													)
													: GridView.builder(
														padding: const EdgeInsets.all(8),
														gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
															crossAxisCount: 4,
															crossAxisSpacing: 8,
															mainAxisSpacing: 8,
														),
														itemCount: _ticketImages.length + 1,
														itemBuilder: (context, index) {
															if (index == _ticketImages.length) {
																return GestureDetector(
																	onTap: _uploadTicketImages,
																	child: Container(
																		decoration: BoxDecoration(
																			border: Border.all(color: Colors.grey.shade300),
																			borderRadius: BorderRadius.circular(8),
																		),
																		child: Icon(Icons.add, color: Colors.grey.shade400),
																	),
																);
															}
															return Stack(
																children: [
																	Container(
																		decoration: BoxDecoration(
																			borderRadius: BorderRadius.circular(8),
																			image: DecorationImage(
																				image: NetworkImage(_ticketImages[index]),
																				fit: BoxFit.cover,
																			),
																		),
																	),
																	Positioned(
																		top: 4,
																		right: 4,
																		child: GestureDetector(
																			onTap: () => setState(() => _ticketImages.removeAt(index)),
																			child: Container(
																				padding: const EdgeInsets.all(2),
																				decoration: const BoxDecoration(
																					color: Colors.red,
																					shape: BoxShape.circle,
																				),
																				child: const Icon(Icons.close, color: Colors.white, size: 16),
																			),
																		),
																	),
																],
															);
														},
													),
											),
											
											const SizedBox(height: 12),
											
											// Upload button
											SizedBox(
												width: double.infinity,
												child: OutlinedButton.icon(
													onPressed: _uploadingImages ? null : _uploadTicketImages,
													icon: _uploadingImages 
														? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
														: const Icon(Icons.upload),
													label: Text(_uploadingImages ? 'Uploading...' : 'Upload Ticket Images (Max 15)'),
													style: OutlinedButton.styleFrom(
														foregroundColor: Colors.blue,
														padding: const EdgeInsets.symmetric(vertical: 12),
													),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Create event button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isCreating ? null : _createEvent,
									icon: _isCreating 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.event),
									label: Text(_isCreating ? 'Creating Event...' : 'Create Event'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.purple.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),

							const SizedBox(height: 16),

							// Info card
							Card(
								color: Colors.purple.shade50,
								child: const Padding(
									padding: EdgeInsets.all(16),
									child: Column(
										children: [
											Icon(Icons.info_outline, color: Colors.purple),
											SizedBox(height: 8),
											Text(
												'Create your event and start selling tickets! You can manage ticket sales, extend event dates, and handle cancellations from your dashboard.',
												textAlign: TextAlign.center,
												style: TextStyle(color: Colors.purple),
											),
										],
									),
								),
							),
						],
					),
				),
			),
		);
	}
}