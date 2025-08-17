import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
	const HomeScreen({super.key});
	@override
	State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
	int _tab = 0;

	String _greeting() {
		final h = DateTime.now().hour;
		if (h < 12) return 'Good morning';
		if (h < 17) return 'Good afternoon';
		return 'Good evening';
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
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const Text('ZippUp! One Tap. All Services.', style: TextStyle(fontSize: 11)),
									Text('${_greeting()} 👋', style: const TextStyle(fontSize: 11)),
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

class _EmergencySection extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return const SizedBox.shrink();
	}
}

class _QuickActions extends StatelessWidget {
	final List<_QuickAction> actions = const [
		_QuickAction('Ride', Icons.local_taxi, 'transport', Color(0xFFFFEDD5)),
		_QuickAction('Food', Icons.fastfood, 'food', Color(0xFFE0F2FE)),
		_QuickAction('Hire', Icons.handyman, 'hire', Color(0xFFEDE9FE)),
		_QuickAction('Marketplace', Icons.store_mall_directory, 'marketplace', Color(0xFFE6F4EA)),
		_QuickAction('Digital', Icons.phone_android, 'digital', Color(0xFFFFE4E6)),
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
					crossAxisCount: 5,
					childAspectRatio: .8,
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
									child: Icon(a.icon, color: Colors.black87),
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
	const _QuickAction(this.title, this.icon, this.routeName, this.bg);
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
						color: index.isEven ? const Color(0xFFFEF3C7) : const Color(0xFFF3E8FF),
						borderRadius: BorderRadius.circular(12),
					),
					padding: const EdgeInsets.all(12),
					child: Text(index.isEven ? '🚑 Emergency services 24/7' : '🍔 10% off first food order', style: const TextStyle(fontWeight: FontWeight.w600)),
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
