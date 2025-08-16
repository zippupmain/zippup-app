import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
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
								children: const [
									Text('ZippUp'),
									SizedBox(height: 2),
									Text('ZippUp! One Tap. All Services.', style: TextStyle(fontSize: 11)),
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
					SliverToBoxAdapter(child: _EmergencySection()),
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
		);
	}
}

class _EmergencySection extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(16),
			child: SizedBox(
				height: 72,
				child: ElevatedButton.icon(
					style: ElevatedButton.styleFrom(
						backgroundColor: Colors.red,
						foregroundColor: Colors.white,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
					),
					icon: const Icon(Icons.warning_amber_rounded),
					label: const Text('Emergency'),
					onPressed: () => context.pushNamed('panic'),
				),
			),
		);
	}
}

class _QuickActions extends StatelessWidget {
	final List<_QuickAction> actions = const [
		_QuickAction('Ride', Icons.local_taxi, 'transport'),
		_QuickAction('Food', Icons.fastfood, 'food'),
		_QuickAction('Hire', Icons.handyman, 'hire'),
		_QuickAction('Marketplace', Icons.store_mall_directory, 'marketplace'),
		_QuickAction('Digital', Icons.phone_android, 'digital'),
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
								CircleAvatar(radius: 24, child: Icon(a.icon)),
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
	const _QuickAction(this.title, this.icon, this.routeName);
}

class _Promotions extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 120,
			child: ListView.separated(
				padding: const EdgeInsets.all(16),
				scrollDirection: Axis.horizontal,
				itemBuilder: (context, index) => Container(
					width: 220,
					decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
					padding: const EdgeInsets.all(12),
					child: const Text('🍔 10% off first food order'),
				),
				separatorBuilder: (_, __) => const SizedBox(width: 12),
				itemCount: 5,
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
				border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
			),
		);
	}
}
