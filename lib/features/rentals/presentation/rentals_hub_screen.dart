import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RentalsHubScreen extends StatelessWidget {
	const RentalsHubScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Rentals')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					Card(
						child: ListTile(
							leading: const Icon(Icons.directions_car),
							title: const Text('Vehicles'),
							subtitle: const Text('Luxury cars, normal cars, bus, truck, tractor'),
							onTap: () => context.pushNamed('rentalVehicles'),
						),
					),
					Card(
						child: ListTile(
							leading: const Icon(Icons.house),
							title: const Text('Houses & Properties'),
							subtitle: const Text('Apartments, shortlets, halls, offices, warehouses'),
							onTap: () => context.pushNamed('rentalHouses'),
						),
					),
					Card(
						child: ListTile(
							leading: const Icon(Icons.build_circle),
							title: const Text('Other rentals'),
							subtitle: const Text('Equipment, instruments, party items, tools'),
							onTap: () => context.pushNamed('rentalOthers'),
						),
					),
				],
			),
		);
	}
}

