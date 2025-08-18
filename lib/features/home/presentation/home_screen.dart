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

	@override
	void initState() {
		super.initState();
		_fetchLocation();
		_setGreeting();
		_checkAdmin();
		FirebaseAuth.instance.authStateChanges().listen((_) {
			_setGreeting();
			_checkAdmin();
		});
	}

	Future<void> _checkAdmin() async {
		try {
			final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
			if (!mounted) return;
			setState(() => _isPlatformAdmin = (token?.claims?['admin'] == true || token?.claims?['role'] == 'admin'));
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

class _EmergencyActions extends StatelessWidget {
	final List<_QuickAction> items = const [
		_QuickAction('Ambulance', Icons.medical_services, 'panic', Color(0xFFFFE5E5), Colors.red),
		_QuickAction('Fire', Icons.local_fire_department, 'panic', Color(0xFFFFE5E5), Colors.red),
		_QuickAction('Towing', Icons.local_shipping, 'panic', Color(0xFFE0F7FA), Colors.blueGrey),
		_QuickAction('Security', Icons.shield_outlined, 'panic', Color(0xFFE8F5E9), Colors.green),
		_QuickAction('Roadside', Icons.build_circle, 'transport', Color(0xFFFFF7E0), Colors.amber),
	];
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Column(
				children: items
					.map((e) => ListTile(leading: Icon(e.icon, color: e.iconColor), title: Text(e.title), onTap: () => context.push('/panic')))
					.toList(),
			),
		);
	}
}

class _DynamicCard extends StatelessWidget {
	final int index;
	const _DynamicCard({required this.index});
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: () => context.push('/marketplace'),
			child: Container(
				margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
				decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]),
				child: ListTile(
					leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.campaign)),
					title: Text('Billboard ${index + 1}'),
					subtitle: const Text('Colorful dynamic billboard content'),
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

class _Promotions extends StatefulWidget {
	@override
	State<_Promotions> createState() => _PromotionsState();
}

class _PromotionsState extends State<_Promotions> {
	final _ctrl = ScrollController();
	Timer? _ticker;
	final List<String> _items = const [
		'🍔 10% off first food order',
		'🚗 Taxi & truck booking',
		'🛠️ Hire verified providers',
		'💳 Pay securely',
		'🛍️ Marketplace deals',
		'🎁 Refer friends, earn coupons',
	];

	void _goFor(String text) {
		final t = text.toLowerCase();
		if (t.contains('taxi') || t.contains('truck')) context.push('/transport');
		else if (t.contains('food') || t.contains('order')) context.push('/food');
		else if (t.contains('hire') || t.contains('verified')) context.push('/hire');
		else if (t.contains('market')) context.push('/marketplace');
		else context.push('/search?q=${Uri.encodeComponent(text)}');
	}

	@override
	void initState() {
		super.initState();
		_ticker = Timer.periodic(const Duration(milliseconds: 25), (_) {
			if (!_ctrl.hasClients) return;
			final max = _ctrl.position.maxScrollExtent;
			final next = _ctrl.offset + 1;
			if (next >= max) {
				_ctrl.jumpTo(0);
			} else {
				_ctrl.jumpTo(next);
			}
		});
	}

	@override
	void dispose() {
		_ticker?.cancel();
		_ctrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final data = [..._items, ..._items];
		return SizedBox(
			height: 140,
			child: Container(
				color: Colors.white,
				child: ListView.separated(
					controller: _ctrl,
					scrollDirection: Axis.horizontal,
					physics: const NeverScrollableScrollPhysics(),
					padding: const EdgeInsets.all(16),
					itemBuilder: (context, index) {
						final text = data[index % data.length];
						return InkWell(
							onTap: () => _goFor(text),
							child: Container(
								width: 260,
								decoration: BoxDecoration(
									color: Colors.white,
									borderRadius: BorderRadius.circular(12),
									border: Border.all(color: Colors.black12),
								),
								padding: const EdgeInsets.all(12),
								child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
							),
						);
					},
					separatorBuilder: (_, __) => const SizedBox(width: 12),
					itemCount: data.length,
				),
			),
		);
	}
}

class _HomeSearchBar extends StatefulWidget {
	@override
	State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
	final controller = TextEditingController();
	final stt.SpeechToText _stt = stt.SpeechToText();
	Future<void> _voice() async {
		final ok = await _stt.initialize(options: [stt.SpeechToText.androidIntentLookup]);
		if (!ok) return;
		await _stt.listen(onResult: (res) {
			if (res.finalResult) {
				controller.text = res.recognizedWords;
				_go();
				_stt.stop();
			}
		});
	}
	void _go() {
		final q = controller.text.trim();
		if (q.isEmpty) return;
		context.push('/search?q=${Uri.encodeComponent(q)}');
	}
	@override
	Widget build(BuildContext context) {
		return TextField(
			controller: controller,
			textInputAction: TextInputAction.search,
			onSubmitted: (_) => _go(),
			decoration: InputDecoration(
				filled: true,
				hintText: 'Search services, vendors, items...',
				prefixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _go),
				suffixIcon: IconButton(icon: const Icon(Icons.mic_none), onPressed: _voice),
				border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
			),
		);
	}
}

class _PositionedUnreadDot extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return StreamBuilder<int>(
			stream: FirebaseFirestore.instance.collection('notifications').where('read', isEqualTo: false).snapshots().map((snapshot) => snapshot.docs.length),
			builder: (context, snapshot) {
				final count = snapshot.data ?? 0;
				if (count == 0) return const SizedBox.shrink();
				return Positioned(
					right: 0,
					top: 0,
					child: Container(
						padding: const EdgeInsets.all(2),
						decoration: BoxDecoration(
							color: Colors.red,
							borderRadius: BorderRadius.circular(6),
						),
						constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
						child: Text(
							count.toString(),
							style: const TextStyle(color: Colors.white, fontSize: 8),
							textAlign: TextAlign.center,
						),
					),
				);
			},
		);
	}
}

class _UserAvatar extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return const CircleAvatar(child: Icon(Icons.person_outline));
		return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
			stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
			builder: (context, snap) {
				String? url;
				if (snap.hasData) {
					url = (snap.data!.data() ?? const {})['photoUrl']?.toString();
				}
				url ??= FirebaseAuth.instance.currentUser?.photoURL;
				if (url == null || url.isEmpty) return const CircleAvatar(child: Icon(Icons.person_outline));
				return CircleAvatar(
					backgroundColor: Colors.grey.shade200,
					radius: 16,
					child: ClipOval(
						child: Image.network(
							url,
							width: 32,
							height: 32,
							fit: BoxFit.cover,
							errorBuilder: (context, error, stack) => const Icon(Icons.person_outline),
						),
					),
				);
			},
		);
	}
}