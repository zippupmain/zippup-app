import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';
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

	@override
	void initState() {
		super.initState();
		_fetchLocation();
		_setGreeting();
		FirebaseAuth.instance.authStateChanges().listen((_) => _setGreeting());
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
			if (pos == null) return;
			final addr = await LocationService.reverseGeocode(pos);
			if (!mounted) return;
			setState(() => _locationText = addr ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
		} catch (_) {}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('ZippUp'),
				actions: [
					IconButton(onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_cart_outlined)),
					IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
					PopupMenuButton(
						icon: const CircleAvatar(child: Icon(Icons.person_outline)),
						itemBuilder: (context) => [
							PopupMenuItem(child: const Text('Profile'), onTap: () => context.push('/profile')),
							PopupMenuItem(child: const Text('Bookings'), onTap: () => context.push('/bookings')),
							PopupMenuItem(child: const Text('Wallet'), onTap: () => context.push('/profile')),
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
						flexibleSpace: const FlexibleSpaceBar(
							titlePadding: EdgeInsetsDirectional.only(start: 16, bottom: 12),
							title: Text('One Tap. All Services.', style: TextStyle(fontSize: 11)),
							background: DecoratedBox(
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
									const SizedBox(width: 8),
									Text(_greet, style: const TextStyle(fontSize: 12)),
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
			padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Padding(
					padding: EdgeInsets.only(bottom: 8),
					child: Text('Emergency Services', style: TextStyle(fontWeight: FontWeight.w600)),
				),
				GridView.builder(
					itemCount: items.length,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: .9, mainAxisSpacing: 10, crossAxisSpacing: 10),
					itemBuilder: (context, i) {
						final a = items[i];
						return InkWell(
							onTap: () => context.pushNamed(a.routeName),
							child: Column(children: [
								Container(decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle), padding: const EdgeInsets.all(12), child: Icon(a.icon, color: a.iconColor)),
								const SizedBox(height: 6),
								Text(a.title, style: const TextStyle(fontSize: 12)),
							]),
						);
					},
				),
			]),
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

class _Promotions extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 140,
			child: ListView.separated(
				padding: const EdgeInsets.all(16),
				scrollDirection: Axis.horizontal,
				itemBuilder: (context, index) => Container(
					width: 260,
					decoration: BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.circular(12),
						border: Border.all(color: Colors.black12),
					),
					padding: const EdgeInsets.all(12),
					child: Text(index.isEven ? '10% off first food order' : 'Taxi & truck booking', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
				),
				separatorBuilder: (_, __) => const SizedBox(width: 12),
				itemCount: 6,
			),
		);
	}
}

class _DynamicCard extends StatelessWidget {
	const _DynamicCard({required this.index});
	final int index;
	@override
	Widget build(BuildContext context) {
		return ListTile(
			title: Text('Recommended item #$index'),
			subtitle: const Text('Nearby and popular'),
			leading: ClipRRect(
				borderRadius: BorderRadius.circular(8),
				child: CachedNetworkImage(
					imageUrl: 'https://picsum.photos/seed/$index/100/100',
					width: 56,
					height: 56,
					fit: BoxFit.cover,
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
				suffixIcon: IconButton(icon: const Icon(Icons.mic_none), onPressed: _go),
				border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
			),
		);
	}
}
