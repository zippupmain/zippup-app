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

// Temporary stubs to unblock build; replace with real implementations
Widget _PositionedUnreadDot() => const SizedBox.shrink();
Widget _HomeSearchBar() => const _HomeSearchBarWidget();
Widget _Promotions() => const SizedBox.shrink();
Widget _DynamicCard({required int index}) => const SizedBox.shrink();

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
			final bottomMargin = kBottomNavigationBarHeight + 120.0; // default a bit above footer
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

	Widget _panicFab() => FloatingActionButton.extended(
		backgroundColor: Colors.red,
		foregroundColor: Colors.white,
		onPressed: () => context.push('/panic'),
		label: const Text('Panic'),
		icon: const Icon(Icons.emergency_share),
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
				title: const Text('ZippUp'),
				actions: [
					IconButton(onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_cart_outlined)),
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '').where('read', isEqualTo: false).snapshots(),
						builder: (context, snap) {
							final unread = (snap.data?.docs.length ?? 0) > 0;
							return IconButton(
								onPressed: () => context.push('/notifications'),
								icon: Stack(children: [
									const Icon(Icons.notifications_none),
									if (unread) const Positioned(right: 0, top: 0, child: Icon(Icons.brightness_1, color: Colors.red, size: 10)),
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
			body: Stack(children:[
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
				// Draggable panic button overlay
				_PositionedDraggablePanic(),
			]),
			bottomNavigationBar: NavigationBar(
				selectedIndex: _tab,
				onDestinationSelected: (i) {
					setState(() => _tab = i);
					if (i == 0) return; if (i == 1) context.push('/bookings'); if (i == 2) context.push('/profile');
				},
				destinations: const [
					NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
					NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Bookings'),
					NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
				],
			),
		);
	}
}

class _QuickActions extends StatelessWidget {
	final List<_QuickAction> actions = const [
		_QuickAction('Ride', Icons.directions_car_filled, 'transport', Color(0xFFFFE5E5), Colors.black),
		_QuickAction('Food', Icons.local_fire_department, 'food', Color(0xFFE8F5E9), Colors.black),
		_QuickAction('Hire', Icons.handyman, 'hire', Color(0xFFFFF7E0), Colors.black),
		_QuickAction('Moving', Icons.local_shipping, 'moving', Color(0xFFE3F2FD), Colors.black),
		_QuickAction('TopUp', Icons.phone_iphone, 'digital', Color(0xFFE8F5E9), Colors.black),
		_QuickAction('Emergency', Icons.emergency_share, 'emergency', Color(0xFFFFE5E5), Colors.black),
		_QuickAction('Others', Icons.category, 'others', Color(0xFFFFE5E5), Colors.black),
		_QuickAction('Personal', Icons.face_3, 'personal', Color(0xFFFFFFFF), Colors.black),
		_QuickAction('Market(P)', Icons.shopping_bag, 'marketplace', Color(0xFFFCE7F3), Colors.black),
		_QuickAction('Rentals', Icons.key, 'rentals', Color(0xFFFFF3E0), Colors.black),
		_QuickAction('Grocery', Icons.local_grocery_store, 'foodVendors', Color(0xFFE8F5E9), Colors.black),
	];

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
			child: Container(
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(12),
					boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
				),
				padding: const EdgeInsets.all(8),
				child: GridView.builder(
					itemCount: actions.length,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
						crossAxisCount: 4,
						childAspectRatio: .9,
						mainAxisSpacing: 10,
						crossAxisSpacing: 10,
					),
					itemBuilder: (context, i) {
						final a = actions[i];
						return InkWell(
							onTap: () {
								if (a.title == 'Grocery') {
									context.push('/food/vendors/grocery');
								} else {
									context.pushNamed(a.routeName);
								}
							},
							child: Column(
								children: [
									Container(
										decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
										padding: const EdgeInsets.all(12),
										child: Icon(a.icon, color: a.iconColor),
									),
									const SizedBox(height: 6),
									Text(a.title, style: const TextStyle(fontSize: 12, color: Colors.black)),
							],
						),
					);
					},
				),
			),
		);
	}
}

class _QuickAction {
	final String title;
	final IconData icon;
	final String routeName;
	final Color bg;
	final Color iconColor;

	const _QuickAction(this.title, this.icon, this.routeName, this.bg, this.iconColor);
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
		if (!kIsWeb) {
			_speech = stt.SpeechToText();
		}
	}

	Future<void> _toggleListen() async {
		if (_listening) {
			_speech?.stop();
			setState(() => _listening = false);
			return;
		}
		if (_speech == null) return;
		final available = await _speech!.initialize(onStatus: (_) {}, onError: (_) {});
		if (!available) return;
		setState(() => _listening = true);
		_speech!.listen(onResult: (r) {
			_controller.text = r.recognizedWords;
			_controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
		});
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
				color: Colors.white,
				borderRadius: BorderRadius.circular(12),
				boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
			),
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			child: Row(children: [
				const Icon(Icons.search, color: Colors.black54),
				const SizedBox(width: 8),
				Expanded(
					child: TextField(
						controller: _controller,
						decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search services, food, vendors, listings...'),
						textInputAction: TextInputAction.search,
						onSubmitted: (_) => _submit(),
					),
				),
				IconButton(
					tooltip: _listening ? 'Stop' : 'Voice search',
					onPressed: kIsWeb ? null : _toggleListen,
					icon: Icon(_listening ? Icons.stop : Icons.mic_none_rounded),
				),
				IconButton(
					onPressed: _submit,
					icon: const Icon(Icons.arrow_forward, color: Colors.black54),
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