import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zippup/features/notifications/widgets/floating_notification.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:zippup/services/localization/app_localizations.dart';
import 'package:zippup/services/notifications/simple_beep_service.dart';
import 'package:zippup/features/debug/widgets/location_debug_widget.dart';
import 'package:zippup/services/location/manual_location_override.dart';

// Enhanced implementations with colorful design
Widget _PositionedUnreadDot() => const SizedBox.shrink();
Widget _HomeSearchBar() => const _HomeSearchBarWidget();
Widget _Promotions() => const _PromotionsCarousel();
Widget _DynamicCard({required int index}) => _ColorfulDynamicCard(index: index);

class _PositionedDraggablePanic extends StatefulWidget {
	@override
	State<_PositionedDraggablePanic> createState() => _PositionedDraggablePanicState();
}

class _PositionedDraggablePanicState extends State<_PositionedDraggablePanic> {
	Offset pos = const Offset(16, 520);
	bool _initialized = false;

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (!_initialized) {
			final size = MediaQuery.of(context).size;
			final dx = (size.width - 160).clamp(8.0, size.width - 80.0);
			final bottomMargin = kBottomNavigationBarHeight + 160.0; // raise a bit more above footer
			final dy = (size.height - bottomMargin).clamp(80.0, size.height - (kBottomNavigationBarHeight + 80.0));
			pos = Offset(dx, dy);
			_initialized = true;
		}
	}
	@override
	Widget build(BuildContext context) {
		return Positioned(
			left: pos.dx,
			top: pos.dy,
			child: GestureDetector(
				onPanUpdate: (details) {
					final size = MediaQuery.of(context).size;
					double dx = (pos.dx + details.delta.dx);
					double dy = (pos.dy + details.delta.dy);
					dx = dx.clamp(8.0, size.width - 80.0);
					dy = dy.clamp(80.0, size.height - (kBottomNavigationBarHeight + 80.0));
					setState(() => pos = Offset(dx, dy));
				},
				child: _panicFab(),
			),
		);
	}

	Widget _panicFab() => Container(
		width: 64,
		height: 64,
		decoration: BoxDecoration(
			gradient: const LinearGradient(
				colors: [Color(0xFFFF1744), Color(0xFFD32F2F)],
				begin: Alignment.topLeft,
				end: Alignment.bottomRight,
			),
			shape: BoxShape.circle,
			boxShadow: [
				BoxShadow(
					color: Colors.red.shade300,
					blurRadius: 12,
					offset: const Offset(0, 6),
					spreadRadius: 2,
				),
			],
		),
		child: FloatingActionButton(
			backgroundColor: Colors.transparent,
			foregroundColor: Colors.white,
			elevation: 0,
			onPressed: () => context.push('/panic'),
			child: const Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Text('🆘', style: TextStyle(fontSize: 20)),
					Text(
						'SOS', 
						style: TextStyle(
							fontWeight: FontWeight.bold, 
							fontSize: 10,
							letterSpacing: 1.0,
						),
					),
				],
			),
		),
	);
}

class HomeScreen extends StatefulWidget {
	const HomeScreen({super.key});
	@override
	State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
	int _tab = 0;
	String _locationText = 'Detecting location…';
	String _greet = '';
	bool _isPlatformAdmin = false;
	StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

	@override
	void initState() {
		super.initState();
		_fetchLocation();
		_setGreeting();
		_checkAdmin();
		FirebaseAuth.instance.authStateChanges().listen((user) {
			_setGreeting();
			_checkAdmin();
			_bindUserListener(user?.uid);
		});
		_bindUserListener(FirebaseAuth.instance.currentUser?.uid);
	}

	void _bindUserListener(String? uid) {
		_userSub?.cancel();
		if (uid == null) return;
		_userSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
			final data = snap.data() ?? const {};
			final name = (data['name']?.toString() ?? '').trim();
			if (name.isNotEmpty) {
				final h = DateTime.now().hour;
				final prefix = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
				if (mounted) setState(() => _greet = '$prefix $name');
			}
		});
	}

	Future<void> _checkAdmin() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;
			final snap = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(uid).get();
			if (!mounted) return;
			setState(() => _isPlatformAdmin = snap.exists);
		} catch (_) {}
	}

	void _setGreeting() {
		final h = DateTime.now().hour;
		final prefix = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
		final u = FirebaseAuth.instance.currentUser;
		final name = (u?.displayName?.trim().isNotEmpty == true)
			? u!.displayName!.trim()
			: (u?.email != null ? u!.email!.split('@').first : 'User');
		setState(() => _greet = '$prefix $name');
	}

	Future<void> _fetchLocation() async {
		try {
			final pos = await LocationService.getCurrentPosition();
			if (!mounted) return;
			if (pos == null) {
				setState(() => _locationText = 'Location unavailable');
				return;
			}
			setState(() => _locationText = 'Detecting location…');
			(() async {
				final addr = await LocationService.reverseGeocode(pos);
				if (!mounted) return;
				if (addr != null && addr.trim().isNotEmpty) {
					setState(() => _locationText = addr);
				} else {
					try {
						final uid = FirebaseAuth.instance.currentUser?.uid;
						if (uid != null) {
							final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
							final fallbackAddr = (u.data() ?? const {})['address']?.toString();
							if (fallbackAddr != null && fallbackAddr.trim().isNotEmpty && mounted) {
								setState(() => _locationText = fallbackAddr);
							} else {
								setState(() => _locationText = 'Location unavailable');
							}
						}
					} catch (_) { setState(() => _locationText = 'Location unavailable'); }
				}
			})();
			LocationService.updateUserLocationProfile(pos).catchError((_) {});
		} catch (_) {
			if (!mounted) return;
			setState(() => _locationText = 'Location unavailable');
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(
					AppLocalizations.of(context)?.appName ?? 'ZippUp',
					style: const TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 22,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
				actions: [
					IconButton(onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_cart_outlined)),
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance
							.collection('notifications')
							.where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
							.where('read', isEqualTo: false)
							.snapshots(),
						builder: (context, snap) {
							final unreadCount = snap.data?.docs.length ?? 0;
							final hasUnread = unreadCount > 0;
							
							return IconButton(
								onPressed: () async {
									// Mark notifications as read when bell is tapped
									if (hasUnread) {
										final uid = FirebaseAuth.instance.currentUser?.uid;
										if (uid != null) {
											final batch = FirebaseFirestore.instance.batch();
											for (final doc in snap.data!.docs) {
												batch.update(doc.reference, {
													'read': true,
													'readAt': FieldValue.serverTimestamp(),
												});
											}
											await batch.commit();
											print('✅ Marked $unreadCount notifications as read from bell tap');
										}
									}
									if (context.mounted) context.push('/notifications');
								},
								icon: Stack(children: [
									const Icon(Icons.notifications_none),
									if (hasUnread) Positioned(
										right: 0, 
										top: 0, 
										child: Container(
											padding: const EdgeInsets.all(2),
											decoration: const BoxDecoration(
												color: Colors.red,
												shape: BoxShape.circle,
											),
											constraints: const BoxConstraints(
												minWidth: 16,
												minHeight: 16,
											),
											child: Text(
												unreadCount > 99 ? '99+' : unreadCount.toString(),
												style: const TextStyle(
													color: Colors.white,
													fontSize: 10,
													fontWeight: FontWeight.bold,
												),
												textAlign: TextAlign.center,
											),
										),
									),
								]),
							);
						},
					),
					PopupMenuButton(
						icon: _UserAvatar(),
						itemBuilder: (context) => <PopupMenuEntry>[
							PopupMenuItem(child: const Text('Profile'), onTap: () => context.push('/profile')),
							PopupMenuItem(child: const Text('Bookings'), onTap: () => context.push('/bookings')),
							PopupMenuItem(child: const Text('Wallet'), onTap: () => context.push('/wallet')),
							PopupMenuItem(
								child: const Text('🔊 Test Notification'),
								onTap: () async {
									// Create a test notification record
									await FirebaseFirestore.instance.collection('notifications').add({
										'userId': FirebaseAuth.instance.currentUser?.uid,
										'title': '🧪 Test Notification',
										'body': 'This is a test notification to verify the bell system works',
										'route': '/notification-test',
										'read': false,
										'createdAt': FieldValue.serverTimestamp(),
									});
									
									// Play simple beep notification
									await SimpleBeepService.instance.playUrgentBeep();
									
									ScaffoldMessenger.of(context).showSnackBar(
										const SnackBar(content: Text('🔔 Test notification created! Check the bell icon.')),
									);
								},
							),
							PopupMenuItem(
								child: const Text('🌍 Location Debug'),
								onTap: () {
									showDialog(
										context: context,
										builder: (context) => Dialog(
											child: Container(
												constraints: const BoxConstraints(maxWidth: 500),
												child: const LocationDebugWidget(),
											),
										),
									);
								},
							),
							PopupMenuItem(
								child: const Text('🌍 Fix Location'),
								onTap: () async {
									// Show location detection and manual override options
									showDialog(
										context: context,
										builder: (context) => AlertDialog(
											title: const Text('🌍 Location Detection'),
											content: const Text('Having issues with currency or address suggestions? Use the location debug tool to fix your location settings.'),
											actions: [
												TextButton(
													onPressed: () => Navigator.pop(context),
													child: const Text('Cancel'),
												),
												ElevatedButton(
													onPressed: () {
														Navigator.pop(context);
														showDialog(
															context: context,
															builder: (context) => Dialog(
																child: Container(
																	constraints: const BoxConstraints(maxWidth: 600),
																	child: const LocationDebugWidget(),
																),
															),
														);
													},
													child: const Text('Open Location Debug'),
												),
											],
										),
									);
								},
							),
							if (_isPlatformAdmin) PopupMenuItem(child: const Text('Platform Admin'), onTap: () => context.push('/admin/platform')),
							const PopupMenuDivider(),
							PopupMenuItem(
								child: const Text('Logout'),
								onTap: () async {
									await FirebaseAuth.instance.signOut();
									if (context.mounted) context.go('/');
								},
							),
						],
					),
				],
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
					),
				),
				child: Stack(children:[
					CustomScrollView(
				slivers: [
					SliverAppBar(
						pinned: true,
						expandedHeight: 120,
						flexibleSpace: FlexibleSpaceBar(
							background: Stack(children: [
								Container(
									decoration: const BoxDecoration(
										gradient: LinearGradient(
											colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
											begin: Alignment.topLeft,
											end: Alignment.bottomRight,
										),
									),
								),
								Align(
									alignment: Alignment.topCenter,
									child: SafeArea(
										child: Padding(
											padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
											child: Container(
												decoration: BoxDecoration(
													color: Colors.black.withOpacity(0.35),
													borderRadius: BorderRadius.circular(20),
												),
												padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
												child: Column(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Row(children: [
															const Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
															const SizedBox(width: 6),
															Expanded(child: Text(_locationText, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12, color: Colors.white))),
															IconButton(onPressed: _fetchLocation, icon: const Icon(Icons.refresh, size: 18, color: Colors.white)),
														]),
														const SizedBox(height: 2),
														Text(_greet, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 1),
													],
												),
											),
										),
									),
								),
							]),
						),
					),
					SliverToBoxAdapter(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
							child: _HomeSearchBar(),
						),
					),
					SliverToBoxAdapter(child: _QuickActions()),
					SliverToBoxAdapter(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
							child: _BillboardCarousel(height: 120),
						),
					),
				],
				),
				// Panic button now in service grid
			]),
			),
			bottomNavigationBar: NavigationBar(
				selectedIndex: _tab,
				onDestinationSelected: (i) {
					setState(() => _tab = i);
					if (i == 0) return; if (i == 1) context.push('/bookings'); if (i == 2) context.push('/hub'); if (i == 3) context.push('/profile');
				},
				destinations: const [
					NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
					NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Bookings'),
					NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Hub'),
					NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
				],
			),
		);
	}
}

class _QuickActions extends StatelessWidget {
	List<_QuickAction> _getActions(BuildContext context) {
		final l = AppLocalizations.of(context);
		return [
			_QuickAction(l?.transport ?? 'Ride', Icons.directions_car_filled, 'transport', 
				const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF21CBF3)]), 
				Colors.white, '🚗'),
			_QuickAction(l?.food ?? 'Food', Icons.restaurant, 'food', 
				const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]), 
				Colors.white, '🍽️'),
			_QuickAction(l?.hire ?? 'Hire', Icons.handyman, 'hire', 
				const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]), 
				Colors.white, '🔧'),
			_QuickAction(l?.moving ?? 'Moving', Icons.local_shipping, 'moving', 
				const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF7986CB)]), 
				Colors.white, '📦'),
			_QuickAction(l?.digital ?? 'TopUp', Icons.phone_iphone, 'digital', 
				const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]), 
				Colors.white, '📱'),
			_QuickAction(l?.emergency ?? 'Emergency', Icons.emergency_share, 'emergency', 
				const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]), 
				Colors.white, '🚨'),
			_QuickAction(l?.others ?? 'Others', Icons.category, 'others', 
				const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF90A4AE)]), 
				Colors.white, '📋'),
			_QuickAction(l?.personal ?? 'Personal', Icons.spa, 'personal', 
				const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF9575CD)]), 
				Colors.white, '💆'),
			_QuickAction(l?.marketplace ?? 'Market', Icons.shopping_bag, 'marketplace', 
				const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]), 
				Colors.white, '🛒'),
			_QuickAction(l?.rentals ?? 'Rentals', Icons.key, 'rentals', 
				const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]), 
				Colors.white, '🏠'),
			_QuickAction(l?.grocery ?? 'Grocery', Icons.local_grocery_store, 'foodVendors', 
				const LinearGradient(colors: [Color(0xFF8BC34A), Color(0xFFAED581)]), 
				Colors.white, '🥬'),
			_QuickAction('SOS', Icons.emergency_share, 'panic', 
				const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD32F2F)]), 
				Colors.white, '🆘'),
		];
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
			child: Container(
				decoration: BoxDecoration(
					gradient: const LinearGradient(
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
						colors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
					),
					borderRadius: BorderRadius.circular(20),
					boxShadow: const [
						BoxShadow(
							color: Color(0x14000000),
							blurRadius: 12,
							offset: Offset(0, 4),
							spreadRadius: 2,
						),
					],
				),
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'🌟 Services',
							style: TextStyle(
								fontSize: 18,
								fontWeight: FontWeight.bold,
								color: Colors.black87,
							),
						),
						const SizedBox(height: 16),
						GridView.builder(
							itemCount: _getActions(context).length,
							shrinkWrap: true,
							physics: const NeverScrollableScrollPhysics(),
							gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
								crossAxisCount: 4,
								childAspectRatio: 0.85,
								mainAxisSpacing: 16,
								crossAxisSpacing: 12,
							),
					itemBuilder: (context, i) {
						final a = _getActions(context)[i];
						return InkWell(
							onTap: () {
								if (a.routeName == 'foodVendors') {
									context.push('/grocery/categories');
								} else {
									context.pushNamed(a.routeName);
								}
							},
							child: Column(
								children: [
									Container(
										width: 56,
										height: 56,
										decoration: BoxDecoration(
											gradient: a.gradient,
											shape: BoxShape.circle,
											boxShadow: [
												BoxShadow(
													color: a.gradient.colors.first.withOpacity(0.3),
													blurRadius: 8,
													offset: const Offset(0, 4),
												),
											],
										),
										child: Stack(
											alignment: Alignment.center,
											children: [
												Icon(a.icon, color: a.iconColor, size: 24),
												Positioned(
													top: 6,
													right: 6,
													child: Text(
														a.emoji,
														style: const TextStyle(fontSize: 16),
													),
												),
											],
										),
									),
									const SizedBox(height: 8),
									Text(
										a.title, 
										style: const TextStyle(
											fontSize: 11, 
											color: Colors.black87,
											fontWeight: FontWeight.w600,
										),
										textAlign: TextAlign.center,
									),
								],
							),
					);
					},
						),
					],
				),
			),
		);
	}
}

class _QuickAction {
	final String title;
	final IconData icon;
	final String routeName;
	final LinearGradient gradient;
	final Color iconColor;
	final String emoji;

	const _QuickAction(this.title, this.icon, this.routeName, this.gradient, this.iconColor, this.emoji);
}

class _HomeSearchBarWidget extends StatefulWidget {
	const _HomeSearchBarWidget();
	@override
	State<_HomeSearchBarWidget> createState() => _HomeSearchBarWidgetState();
}

class _HomeSearchBarWidgetState extends State<_HomeSearchBarWidget> {
	final TextEditingController _controller = TextEditingController();
	stt.SpeechToText? _speech;
	bool _listening = false;

	@override
	void initState() {
		super.initState();
		// Initialize speech for all platforms
		_speech = stt.SpeechToText();
	}

	Future<void> _toggleListen() async {
		print('🎤 Voice search toggle pressed, listening: $_listening');
		
		if (_listening) {
			_speech?.stop();
			setState(() => _listening = false);
			print('🛑 Voice search stopped');
			return;
		}
		
		if (_speech == null) {
			print('❌ Speech service not initialized');
			return;
		}
		
		try {
			print('🔄 Initializing speech recognition...');
			final available = await _speech!.initialize(
				onStatus: (status) {
					print('🎤 Speech status: $status');
				}, 
				onError: (error) {
					print('❌ Speech error: $error');
					if (mounted) {
						setState(() => _listening = false);
						ScaffoldMessenger.of(context).showSnackBar(
							SnackBar(content: Text('Voice search error: ${error.errorMsg}')),
						);
					}
				}
			);
			
			if (!available) {
				print('❌ Speech recognition not available on this device');
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('Voice search not available on this device')),
					);
				}
				return;
			}
			
			print('✅ Speech recognition initialized, starting to listen...');
			setState(() => _listening = true);
			
			_speech!.listen(
				onResult: (result) {
					print('🎤 Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
					
					// Only update text on final result to avoid duplicates
					if (result.finalResult) {
						final newText = result.recognizedWords.trim();
						if (newText.isNotEmpty && newText != _controller.text) {
							_controller.text = newText;
							_controller.selection = TextSelection.fromPosition(
								TextPosition(offset: _controller.text.length)
							);
						}
					}
				},
				listenFor: const Duration(seconds: 30),
				pauseFor: const Duration(seconds: 3),
			);
		} catch (e) {
			print('❌ Speech initialization failed: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Voice search failed: $e')),
				);
			}
		}
	}

	void _submit() {
		final q = _controller.text.trim();
		if (q.isEmpty) return;
		if (context.mounted) context.pushNamed('search', queryParameters: {'q': q});
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				gradient: const LinearGradient(
					colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
				borderRadius: BorderRadius.circular(16),
				boxShadow: const [
					BoxShadow(
						color: Colors.blue,
						blurRadius: 12,
						offset: Offset(0, 4),
						spreadRadius: -2,
					),
				],
			),
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
			child: Row(children: [
				Container(
					padding: const EdgeInsets.all(8),
					decoration: BoxDecoration(
						color: Colors.white.withOpacity(0.9),
						shape: BoxShape.circle,
					),
					child: const Icon(Icons.search, color: Colors.blue, size: 20),
				),
				const SizedBox(width: 12),
				Expanded(
					child: TextField(
						controller: _controller,
						decoration: const InputDecoration(
							border: InputBorder.none, 
							hintText: '🔍 Search services, food, vendors, listings...',
							hintStyle: TextStyle(color: Colors.blue),
						),
						style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
						textInputAction: TextInputAction.search,
						onSubmitted: (_) => _submit(),
					),
				),
				Container(
					margin: const EdgeInsets.only(left: 8),
					decoration: BoxDecoration(
						gradient: LinearGradient(
							colors: _listening 
								? [Colors.red.shade400, Colors.red.shade600]
								: [Colors.blue.shade400, Colors.blue.shade600],
						),
						shape: BoxShape.circle,
						boxShadow: [
							BoxShadow(
								color: _listening ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
								blurRadius: 8,
								spreadRadius: 2,
							),
						],
					),
					child: IconButton(
						tooltip: _listening ? 'Stop voice search' : 'Start voice search',
						onPressed: _toggleListen, // Enable for all platforms
						icon: Icon(
							_listening ? Icons.stop : Icons.mic,
							color: Colors.white,
							size: 22,
						),
					),
				),
				Container(
					margin: const EdgeInsets.only(left: 8),
					decoration: BoxDecoration(
						gradient: const LinearGradient(
							colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
						),
						shape: BoxShape.circle,
					),
					child: IconButton(
						onPressed: _submit,
						icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
					),
				),
			]),
		);
	}
}

class _BillboardCarousel extends StatefulWidget {
	final double height;
	const _BillboardCarousel({required this.height});
	@override
	State<_BillboardCarousel> createState() => _BillboardCarouselState();
}

class _BillboardCarouselState extends State<_BillboardCarousel> {
	final PageController _controller = PageController(viewportFraction: 0.88);
	int _index = 0;
	int _slidesCount = 4;
	@override
	void initState() {
		super.initState();
		Future.microtask(() async {
			while (mounted) {
				await Future.delayed(const Duration(seconds: 4));
				if (!mounted) break;
				if (!_controller.hasClients) continue;
				final total = _slidesCount <= 0 ? 1 : _slidesCount;
				final current = _controller.page?.round() ?? 0;
				final next = (current + 1) % total;
				await _controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
			}
		});
	}
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: widget.height,
			child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('_config').doc('promos').snapshots(),
				builder: (context, configSnap) {
					final mode = (configSnap.data?.data()?['mode'] ?? 'local').toString();
					if (mode == 'firestore') {
						return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: FirebaseFirestore.instance.collection('promos').orderBy('createdAt', descending: true).limit(5).snapshots(),
							builder: (context, snapshot) {
								final docs = snapshot.data?.docs ?? const [];
								// Update slide count for auto-scroll loop
								_slidesCount = docs.isEmpty ? 4 : docs.length;
								if (docs.isEmpty) {
									return _buildLocalPromos();
								}
								return PageView.builder(
									controller: _controller,
									itemCount: docs.length,
									itemBuilder: (context, i) {
										final data = docs[i].data();
										return _BillboardCard(
											title: (data['title'] ?? '').toString(),
											subtitle: (data['subtitle'] ?? data['description'] ?? '').toString(),
											imageUrl: (data['imageUrl'] ?? '').toString().isEmpty ? null : (data['imageUrl'] as String),
										);
									},
								);
							},
						);
					}
					return _buildLocalPromos();
				},
			),
		);
	}

	Widget _buildLocalPromos() {
		return PageView(
			controller: _controller,
			children: const [
				_BillboardCard(
					title: 'Pizza specials near you',
					subtitle: 'Order hot and fresh in minutes',
					assetPath: 'assets/promos/pizza.jpg',
				),
				_BillboardCard(
					title: 'Need a ride or bus charter?',
					subtitle: 'Transport, taxi, and group travel',
					assetPath: 'assets/promos/transport.jpg',
				),
				_BillboardCard(
					title: 'Pay securely with ZippUp',
					subtitle: 'Cards, wallets, and local methods',
					assetPath: 'assets/promos/payments.jpg',
				),
				_BillboardCard(
					title: 'Marketplace deals',
					subtitle: 'Buy and sell with confidence',
					assetPath: 'assets/promos/marketplace.jpg',
				),
			],
		);
	}
}

class _BillboardCard extends StatelessWidget {
	final String title;
	final String subtitle;
	final String? imageUrl;
	final String? assetPath;
	const _BillboardCard({required this.title, required this.subtitle, this.imageUrl, this.assetPath});
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 6),
			child: InkWell(
				onTap: () {
					final t = title.toLowerCase();
					if (t.contains('ride') || t.contains('charter') || t.contains('bus')) context.push('/transport');
					else if (t.contains('plumber') || t.contains('plumbers')) context.push('/hire');
					else if (t.contains('food') || t.contains('pizza')) context.push('/food');
					else if (t.contains('pay') || t.contains('wallet')) context.push('/wallet');
					else if (t.contains('market')) context.push('/marketplace');
				},
				child: Container(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(12),
						gradient: (imageUrl == null && assetPath == null)
							? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)])
							: null,
						color: (imageUrl == null && assetPath == null) ? null : Colors.white,
						boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
					),
					clipBehavior: Clip.antiAlias,
					child: Stack(
						fit: StackFit.expand,
						children: [
							if (assetPath != null)
								Image.asset(
									assetPath!,
									fit: BoxFit.cover,
									errorBuilder: (_, __, ___) => imageUrl != null
										? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
										: const SizedBox.shrink(),
								),
							if (assetPath == null && imageUrl != null)
								CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
							Container(
								decoration: BoxDecoration(
									gradient: LinearGradient(
										colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.5)],
										begin: Alignment.topCenter,
										end: Alignment.bottomCenter,
									),
								),
							),
						Padding(
							padding: const EdgeInsets.all(12),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
									const SizedBox(height: 4),
									Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 12)),
								],
							),
						),
					],
					),
				),
			),
		);
	}
}

class _UserAvatar extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final u = FirebaseAuth.instance.currentUser;
		String? url = u?.photoURL;
		if (url != null && url.isNotEmpty) {
			// Rewrite storage domain if needed for web CORS
			if (url.contains('firebasestorage.app')) {
				url = url.replaceFirst('firebasestorage.app', 'appspot.com');
			}
			return ClipOval(
				child: Image.network(
					url,
					width: 28,
					height: 28,
					fit: BoxFit.cover,
					errorBuilder: (_, __, ___) => const Icon(Icons.person),
				),
			);
		}
		return const Icon(Icons.person);
	}
}

class _PromotionsCarousel extends StatelessWidget {
	const _PromotionsCarousel();
	
	@override
	Widget build(BuildContext context) {
		final promotions = [
			{
				'title': '🍕 Free Delivery Weekend',
				'subtitle': 'Order food with no delivery fees',
				'gradient': const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
				'action': 'Order Now',
			},
			{
				'title': '🚗 50% Off First Ride',
				'subtitle': 'New users get huge discounts',
				'gradient': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
				'action': 'Book Ride',
			},
			{
				'title': '🔧 Hire Services Sale',
				'subtitle': 'Professional services at best prices',
				'gradient': const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
				'action': 'Hire Now',
			},
		];
		
		return Container(
			height: 120,
			margin: const EdgeInsets.symmetric(horizontal: 16),
			child: PageView.builder(
				itemCount: promotions.length,
				itemBuilder: (context, index) {
					final promo = promotions[index];
					return Container(
						margin: const EdgeInsets.symmetric(horizontal: 4),
						decoration: BoxDecoration(
							gradient: promo['gradient'] as LinearGradient,
							borderRadius: BorderRadius.circular(16),
							boxShadow: [
								BoxShadow(
									color: (promo['gradient'] as LinearGradient).colors.first.withOpacity(0.3),
									blurRadius: 8,
									offset: const Offset(0, 4),
								),
							],
						),
						child: Padding(
							padding: const EdgeInsets.all(16),
							child: Row(
								children: [
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Text(
													promo['title'] as String,
													style: const TextStyle(
														color: Colors.white,
														fontWeight: FontWeight.bold,
														fontSize: 16,
													),
												),
												const SizedBox(height: 4),
												Text(
													promo['subtitle'] as String,
													style: const TextStyle(
														color: Colors.white,
														fontSize: 12,
													),
												),
											],
										),
									),
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
										decoration: BoxDecoration(
											color: Colors.white.withOpacity(0.2),
											borderRadius: BorderRadius.circular(20),
										),
										child: Text(
											promo['action'] as String,
											style: const TextStyle(
												color: Colors.white,
												fontWeight: FontWeight.bold,
												fontSize: 12,
											),
										),
									),
								],
							),
						),
					);
				},
			),
		);
	}
}

class _ColorfulDynamicCard extends StatelessWidget {
	const _ColorfulDynamicCard({required this.index});
	final int index;
	
	@override
	Widget build(BuildContext context) {
		final cards = [
			{
				'title': '⚡ Quick Services',
				'subtitle': 'Emergency & instant help',
				'gradient': const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]),
				'icon': Icons.flash_on,
			},
			{
				'title': '🎯 Popular Now',
				'subtitle': 'Trending services in your area',
				'gradient': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
				'icon': Icons.trending_up,
			},
			{
				'title': '💎 Premium Services',
				'subtitle': 'High-quality verified providers',
				'gradient': const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF9575CD)]),
				'icon': Icons.diamond,
			},
		];
		
		if (index >= cards.length) return const SizedBox.shrink();
		
		final card = cards[index];
		return Container(
			margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				gradient: card['gradient'] as LinearGradient,
				borderRadius: BorderRadius.circular(12),
				boxShadow: [
					BoxShadow(
						color: (card['gradient'] as LinearGradient).colors.first.withOpacity(0.3),
						blurRadius: 6,
						offset: const Offset(0, 3),
					),
				],
			),
			child: Padding(
				padding: const EdgeInsets.all(12),
				child: Row(
					children: [
						Container(
							padding: const EdgeInsets.all(8),
							decoration: BoxDecoration(
								color: Colors.white.withOpacity(0.2),
								shape: BoxShape.circle,
							),
							child: Icon(
								card['icon'] as IconData,
								color: Colors.white,
								size: 20,
							),
						),
						const SizedBox(width: 12),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										card['title'] as String,
										style: const TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.bold,
											fontSize: 14,
										),
									),
									const SizedBox(height: 2),
									Text(
										card['subtitle'] as String,
										style: const TextStyle(
											color: Colors.white,
											fontSize: 11,
										),
									),
								],
							),
						),
					],
				),
			),
		);
	}
}