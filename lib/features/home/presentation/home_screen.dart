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

// Temporary stubs to unblock build; replace with real implementations
Widget _PositionedUnreadDot() => const SizedBox.shrink();
Widget _UserAvatar() => const Icon(Icons.person);
Widget _HomeSearchBar() => const SizedBox.shrink();
Widget _Promotions() => const SizedBox.shrink();
Widget _DynamicCard({required int index}) => const SizedBox.shrink();

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
			// Keep detecting text; resolve to address
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
					IconButton(
						onPressed: () => context.push('/notifications'),
						icon: Stack(children: [
							const Icon(Icons.notifications_none),
							_PositionedUnreadDot(),
						]),
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
			body: CustomScrollView(
				slivers: [
					SliverAppBar(
						pinned: true,
						expandedHeight: 160,
						flexibleSpace: FlexibleSpaceBar(
							titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
							title: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									Text(_greet, style: const TextStyle(fontSize: 11)),
									const SizedBox(height: 2),
									const Text('One Tap. All Services.', style: TextStyle(fontSize: 11)),
								],
							),
							background: const DecoratedBox(
								decoration: BoxDecoration(
									gradient: LinearGradient(
										colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
										begin: Alignment.topLeft,
										end: Alignment.bottomRight,
									),
								),
							),
						),
					),
					SliverToBoxAdapter(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
							child: Row(
								children: [
									const Icon(Icons.location_on_outlined, size: 18, color: Colors.redAccent),
									const SizedBox(width: 6),
									Expanded(child: Text(_locationText, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12))),
									IconButton(onPressed: _fetchLocation, icon: const Icon(Icons.refresh, size: 18)),
								],
							),
						),
					),
					SliverToBoxAdapter(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
							child: _HomeSearchBar(),
						),
					),
					SliverToBoxAdapter(child: _QuickActions()),
					SliverToBoxAdapter(child: _Promotions()),
					SliverList(
						delegate: SliverChildBuilderDelegate(
							(context, index) => _DynamicCard(index: index),
							childCount: 8,
						),
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				backgroundColor: Colors.red,
				foregroundColor: Colors.white,
				onPressed: () => context.push('/panic'),
				label: const Text('Panic'),
				icon: const Icon(Icons.emergency_share),
			),
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
		_QuickAction('Marketplace', Icons.shopping_bag, 'marketplace', Color(0xFFFCE7F3), Colors.black),
		_QuickAction('Digital', Icons.devices_other, 'digital', Color(0xFFE8F5E9), Colors.black),
		_QuickAction('Emergency', Icons.emergency_share, 'emergency', Color(0xFFFFE5E5), Colors.black),
		_QuickAction('Others', Icons.category, 'others', Color(0xFFFFE5E5), Colors.black),
		_QuickAction('Personal', Icons.face_3, 'personal', Color(0xFFFFFFFF), Colors.black),
		_QuickAction('Moving', Icons.local_shipping, 'moving', Color(0xFFE3F2FD), Colors.black),
		_QuickAction('Rentals', Icons.key, 'rentals', Color(0xFFFFF3E0), Colors.black),
	];

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
						onTap: () => context.pushNamed(a.routeName),
						child: Column(
							children: [
								Container(
									decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
									padding: const EdgeInsets.all(12),
									child: Icon(a.icon, color: a.iconColor),
								),
								const SizedBox(height: 6),
								Text(a.title, style: const TextStyle(fontSize: 12)),
							],
						),
					);
				},
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