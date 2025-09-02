import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class TransportProviderDashboardScreen extends StatefulWidget {
	const TransportProviderDashboardScreen({super.key});
	@override
	State<TransportProviderDashboardScreen> createState() => _TransportProviderDashboardScreenState();
}

class _TransportProviderDashboardScreenState extends State<TransportProviderDashboardScreen> with SingleTickerProviderStateMixin {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = true;
	RideStatus? _filter;
	Stream<List<Ride>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		
		// Auto-migrate profile with new features
		await _autoMigrateProfile();
		
		// read availability from provider_profiles
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'transport').limit(1).get();
		if (snap.docs.isNotEmpty) {
			// Always default to online, update profile
			_online = true;
			await _db.collection('provider_profiles').doc(snap.docs.first.id).update({'availabilityOnline': true});
			if (mounted) setState(() {});
		}
		// incoming assigned ride requests (requested and addressed to me)
		_incomingStream = _db
			.collection('rides')
			.where('driverId', isEqualTo: uid)
			.where('status', isEqualTo: RideStatus.requested.name)
			.snapshots()
			.map((s) => s.docs.map((d) => Ride.fromJson(d.id, d.data())).toList());
	}

	Future<void> _autoMigrateProfile() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;

			final providerDoc = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: 'transport')
				.limit(1)
				.get();

			if (providerDoc.docs.isNotEmpty) {
				final data = providerDoc.docs.first.data();
				final updateData = <String, dynamic>{};

				// Add missing fields for new features
				if (!data.containsKey('enabledRoles')) {
					final serviceType = data['serviceType']?.toString() ?? 'taxi';
					updateData['enabledRoles'] = {serviceType: true};
				}
				if (!data.containsKey('enabledClasses')) {
					final serviceType = data['serviceType']?.toString() ?? 'taxi';
					updateData['enabledClasses'] = {serviceType: true};
				}
				if (!data.containsKey('operationalRadius')) {
					updateData['operationalRadius'] = 25.0;
				}
				if (!data.containsKey('hasRadiusLimit')) {
					updateData['hasRadiusLimit'] = false;
				}

				// Update profile if needed
				if (updateData.isNotEmpty) {
					updateData['autoMigratedAt'] = FieldValue.serverTimestamp();
					await providerDoc.docs.first.reference.update(updateData);
					
					// Show user that profile was updated
					if (mounted) {
						ScaffoldMessenger.of(context).showSnackBar(
							const SnackBar(
								content: Text('✅ Profile updated! Vehicle Types and Settings now available.'),
								backgroundColor: Colors.green,
								duration: Duration(seconds: 3),
							),
						);
					}
				}
			}
		} catch (e) {
			print('Error during transport auto-migration: $e');
		}
	}

	Stream<List<Ride>> _ridesStream(String uid) {
		Query<Map<String,dynamic>> q = _db.collection('rides').where('driverId', isEqualTo: uid);
		return q.snapshots().map((s) => s.docs.map((d) => Ride.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'transport').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateRide(String id, RideStatus status) async {
		final uid = _auth.currentUser?.uid;
		await _db.collection('rides').doc(id).set({'status': status.name, if (status == RideStatus.accepted && uid != null) 'driverId': uid}, SetOptions(merge: true));
	}

	Future<void> _navigateToServiceRoles() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				final providerDoc = await FirebaseFirestore.instance
					.collection('provider_profiles')
					.where('userId', isEqualTo: uid)
					.where('service', isEqualTo: 'transport')
					.limit(1)
					.get();
				
				if (providerDoc.docs.isNotEmpty) {
					final subcategory = providerDoc.docs.first.data()['subcategory']?.toString() ?? 'taxi';
					context.push('/service-roles/transport/$subcategory');
				} else {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('❌ Transport profile not found. Please create a profile first.')),
					);
				}
			}
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error: $e')),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(
					title: const Text('🚗 Transport Business'),
					backgroundColor: Colors.blue.shade50,
					iconTheme: const IconThemeData(color: Colors.black),
					titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
					actions: [
						IconButton(
							icon: const Icon(Icons.settings),
							onPressed: () => context.push('/operational-settings/transport'),
							tooltip: 'Operational Settings',
						),
						PopupMenuButton<String>(
							icon: const Icon(Icons.more_vert),
							onSelected: (value) {
								switch (value) {
									case 'roles':
										_navigateToServiceRoles();
										break;
									case 'settings':
										context.push('/operational-settings/transport');
										break;
									case 'home':
										context.go('/');
										break;
								}
							},
							itemBuilder: (context) => [
								const PopupMenuItem(
									value: 'roles',
									child: ListTile(
										leading: Icon(Icons.tune),
										title: Text('Vehicle Types'),
										dense: true,
									),
								),
								const PopupMenuItem(
									value: 'settings',
									child: ListTile(
										leading: Icon(Icons.settings),
										title: Text('Operational Settings'),
										dense: true,
									),
								),
								const PopupMenuItem(
									value: 'home',
									child: ListTile(
										leading: Icon(Icons.home),
										title: Text('Home'),
										dense: true,
									),
								),
							],
						),
					],
					bottom: PreferredSize(
						preferredSize: const Size.fromHeight(48),
						child: StreamBuilder<List<Ride>>(
							stream: _incomingStream,
							builder: (context, s) {
								final count = (s.data?.length ?? 0);
								return TabBar(tabs: [
									Tab(
										icon: count > 0 ? Badge(
											label: Text('$count'),
											child: const Icon(Icons.notifications_active),
										) : const Icon(Icons.notifications_active),
										text: count > 0 ? 'New ($count)' : 'New Rides',
									),
									const Tab(icon: Icon(Icons.history), text: 'All History'),
								]);
							},
						),
					),
				),
				body: Column(
					children: [
						const ProviderHeader(service: 'transport'),
						
						// Enhanced online toggle and features
						Container(
							color: Colors.blue.shade50,
							padding: const EdgeInsets.all(16),
							child: Column(
								children: [
									// Online status with enhanced UI
									Card(
										elevation: 2,
										child: Container(
											padding: const EdgeInsets.all(16),
											decoration: BoxDecoration(
												borderRadius: BorderRadius.circular(12),
												gradient: LinearGradient(
													colors: [
														_online ? Colors.green.shade100 : Colors.grey.shade100,
														_online ? Colors.green.shade50 : Colors.grey.shade50,
													],
												),
											),
											child: Row(
												children: [
													Icon(
														_online ? Icons.directions_car : Icons.car_rental,
														color: _online ? Colors.green.shade700 : Colors.grey.shade600,
														size: 32,
													),
													const SizedBox(width: 16),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(
																	_online ? '🟢 Online - Accepting Rides' : '🔴 Offline - Not Accepting',
																	style: TextStyle(
																		fontWeight: FontWeight.bold,
																		fontSize: 16,
																		color: _online ? Colors.green.shade800 : Colors.red.shade800,
																	),
																),
																Text(
																	_online ? 'Ready to receive ride requests' : 'Go online to start earning',
																	style: const TextStyle(color: Colors.grey, fontSize: 12),
																),
															],
														),
													),
													Switch(
														value: _online,
														onChanged: _setOnline,
														activeColor: Colors.green,
													),
												],
											),
										),
									),
									
									const SizedBox(height: 16),
									
									// Quick access features
									Row(
										children: [
											Expanded(
												child: ElevatedButton.icon(
													onPressed: () => _navigateToServiceRoles(),
													icon: const Icon(Icons.directions_car),
													label: const Text('Vehicle Types'),
													style: ElevatedButton.styleFrom(
														backgroundColor: Colors.blue,
														foregroundColor: Colors.white,
														padding: const EdgeInsets.symmetric(vertical: 12),
													),
												),
											),
											const SizedBox(width: 8),
											Expanded(
												child: ElevatedButton.icon(
													onPressed: () => context.push('/operational-settings/transport'),
													icon: const Icon(Icons.settings),
													label: const Text('Settings'),
													style: ElevatedButton.styleFrom(
														backgroundColor: Colors.green,
														foregroundColor: Colors.white,
														padding: const EdgeInsets.symmetric(vertical: 12),
													),
												),
											),
										],
									),
								],
							),
						),

						// Status filters
						Container(
							color: Colors.white,
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
							child: SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: [
										FilterChip(
											label: const Text('📋 All History'),
											selected: _filter == null,
											onSelected: (_) => setState(() => _filter = null),
											backgroundColor: Colors.blue.shade50,
										),
										const SizedBox(width: 8),
										...RideStatus.values.map((s) => Padding(
											padding: const EdgeInsets.symmetric(horizontal: 4),
											child: FilterChip(
												label: Text(s.name),
												selected: _filter == s,
												onSelected: (_) => setState(() => _filter = s),
												backgroundColor: _filter == s ? Colors.blue.shade100 : Colors.grey.shade100,
											),
										)),
									],
								),
							),
						),

						// Tabs content
						Expanded(
							child: TabBarView(
								children: [
									// New rides tab
									StreamBuilder<List<Ride>>(
										stream: _incomingStream,
										builder: (context, s) {
											if (!s.hasData) return const Center(child: CircularProgressIndicator());
											final list = s.data ?? const <Ride>[];
											if (list.isEmpty) return const Center(child: Text('No new ride requests'));
											return ListView.separated(
												itemCount: list.length,
												separatorBuilder: (_, __) => const Divider(height: 1),
												itemBuilder: (context, i) {
													final r = list[i];
													return Card(
														margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
														elevation: 2,
														child: ListTile(
															title: Text('🚗 Ride ${r.id.substring(0,6)} • ${r.type.name.toUpperCase()}'),
															subtitle: Text('From: ${r.pickupAddress}\nTo: ${r.destinationAddresses.isNotEmpty ? r.destinationAddresses.first : 'Unknown'}'),
															trailing: Wrap(spacing: 8, children: _actionsFor(r)),
															isThreeLine: true,
														),
													);
												},
											);
										},
									),
									
									// All rides history tab
									StreamBuilder<List<Ride>>(
										stream: _ridesStream(uid),
										builder: (context, snap) {
											if (!snap.hasData) return const Center(child: CircularProgressIndicator());
											var rides = snap.data!;
											if (_filter != null) rides = rides.where((r) => r.status == _filter).toList();
											if (rides.isEmpty) return const Center(child: Text('No ride history'));
											return ListView.separated(
												itemCount: rides.length,
												separatorBuilder: (_, __) => const Divider(height: 1),
												itemBuilder: (context, i) {
													final r = rides[i];
													return Card(
														margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
														elevation: 2,
														child: ListTile(
															leading: CircleAvatar(
																backgroundColor: _getStatusColor(r.status),
																child: Text(_getStatusIcon(r.status)),
															),
															title: Text('🚗 Ride ${r.id.substring(0,6)} • ${r.type.name.toUpperCase()}'),
															subtitle: Text('Status: ${r.status.name.toUpperCase()}\nFrom: ${r.pickupAddress}\nTo: ${r.destinationAddresses.isNotEmpty ? r.destinationAddresses.first : 'Unknown'}'),
															trailing: _buildHistoryActions(r),
															isThreeLine: true,
															onTap: () => context.push('/track/ride?rideId=${r.id}'),
														),
													);
												},
											);
										},
									),
								],
							),
						),
					],
				),
			),
		);
	}

	Color _getStatusColor(RideStatus status) {
		switch (status) {
			case RideStatus.completed:
				return Colors.green.shade100;
			case RideStatus.cancelled:
				return Colors.red.shade100;
			case RideStatus.enroute:
				return Colors.blue.shade100;
			case RideStatus.accepted:
				return Colors.orange.shade100;
			default:
				return Colors.grey.shade100;
		}
	}

	String _getStatusIcon(RideStatus status) {
		switch (status) {
			case RideStatus.completed:
				return '✅';
			case RideStatus.cancelled:
				return '❌';
			case RideStatus.enroute:
				return '🚗';
			case RideStatus.accepted:
				return '📋';
			default:
				return '📋';
		}
	}

	Widget _buildHistoryActions(Ride ride) {
		switch (ride.status) {
			case RideStatus.completed:
				return const Icon(Icons.check_circle, color: Colors.green);
			case RideStatus.cancelled:
				return const Icon(Icons.cancel, color: Colors.red);
			case RideStatus.accepted:
			case RideStatus.arriving:
			case RideStatus.arrived:
			case RideStatus.enroute:
				return ElevatedButton(
					onPressed: () => context.push('/track/ride?rideId=${ride.id}'),
					style: ElevatedButton.styleFrom(
						backgroundColor: Colors.blue,
						foregroundColor: Colors.white,
						minimumSize: const Size(60, 32),
					),
					child: const Text('Track'),
				);
			default:
				return const SizedBox.shrink();
		}
	}

	List<Widget> _actionsFor(Ride r) {
		switch (r.status) {
			case RideStatus.requested:
				return [
					FilledButton(onPressed: () => _updateRide(r.id, RideStatus.accepted), child: const Text('Accept')),
					TextButton(onPressed: () => _db.collection('rides').doc(r.id).set({ 'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp() }, SetOptions(merge: true)), child: const Text('Decline')),
				];
			case RideStatus.accepted:
				return [TextButton(onPressed: () => _updateRide(r.id, RideStatus.arriving), child: const Text('Arriving'))];
			case RideStatus.arriving:
				return [TextButton(onPressed: () => _updateRide(r.id, RideStatus.arrived), child: const Text('Arrived'))];
			case RideStatus.arrived:
				return [FilledButton(onPressed: () => _updateRide(r.id, RideStatus.enroute), child: const Text('Start trip'))];
			case RideStatus.enroute:
				return [FilledButton(onPressed: () => _updateRide(r.id, RideStatus.completed), child: const Text('Complete'))];
			default:
				return const [];
		}
	}
}