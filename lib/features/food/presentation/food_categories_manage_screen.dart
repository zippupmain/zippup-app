import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class FoodCategoriesManageScreen extends StatefulWidget {
	const FoodCategoriesManageScreen({super.key});

	@override
	State<FoodCategoriesManageScreen> createState() => _FoodCategoriesManageScreenState();
}

class _FoodCategoriesManageScreenState extends State<FoodCategoriesManageScreen> {
	List<String> _selectedCategories = [];
	bool _isLoading = true;
	bool _isSaving = false;

	final Map<String, Map<String, dynamic>> _allFoodCategories = {
		'fast_food': {
			'name': 'Fast Food',
			'emoji': '🍔',
			'description': 'Burgers, fries, quick meals',
			'examples': ['Burgers', 'Fries', 'Chicken', 'Sandwiches'],
		},
		'local': {
			'name': 'Local Cuisine',
			'emoji': '🍲',
			'description': 'Traditional local dishes',
			'examples': ['Jollof Rice', 'Fried Rice', 'Soup', 'Stew'],
		},
		'pizza': {
			'name': 'Pizza',
			'emoji': '🍕',
			'description': 'Pizza and Italian dishes',
			'examples': ['Margherita', 'Pepperoni', 'Pasta', 'Calzone'],
		},
		'continental': {
			'name': 'Continental',
			'emoji': '🥡',
			'description': 'International cuisines',
			'examples': ['African', 'Asian', 'American', 'European', 'Mediterranean', 'Middle Eastern'],
		},
		'desserts': {
			'name': 'Desserts',
			'emoji': '🍰',
			'description': 'Sweet treats and desserts',
			'examples': ['Cakes', 'Ice Cream', 'Pastries', 'Cookies'],
		},
		'drinks': {
			'name': 'Drinks',
			'emoji': '🥤',
			'description': 'Beverages and drinks',
			'examples': ['Smoothies', 'Juices', 'Coffee', 'Tea', 'Soft Drinks'],
		},
		'bakery': {
			'name': 'Bakery',
			'emoji': '🥖',
			'description': 'Fresh baked goods',
			'examples': ['Bread', 'Croissants', 'Muffins', 'Donuts'],
		},
	};

	@override
	void initState() {
		super.initState();
		_loadCurrentCategories();
	}

	Future<void> _loadCurrentCategories() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				final vendorDoc = await FirebaseFirestore.instance
					.collection('vendors')
					.doc(uid)
					.get();

				if (vendorDoc.exists) {
					final data = vendorDoc.data()!;
					final categories = (data['foodCategories'] as List<dynamic>?)?.cast<String>() ?? [];
					setState(() {
						_selectedCategories = categories;
					});
				}
			}
		} catch (e) {
			print('Error loading categories: $e');
		} finally {
			setState(() => _isLoading = false);
		}
	}

	Future<void> _saveCategories() async {
		if (_selectedCategories.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please select at least one food category'))
			);
			return;
		}

		setState(() => _isSaving = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				await FirebaseFirestore.instance
					.collection('vendors')
					.doc(uid)
					.update({
						'foodCategories': _selectedCategories,
						'lastUpdated': DateTime.now().toIso8601String(),
					});

				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
							content: Text('✅ Food categories updated successfully!'),
							backgroundColor: Colors.green,
						)
					);
					context.pop();
				}
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed to update categories: $e'))
				);
			}
		} finally {
			if (mounted) setState(() => _isSaving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_isLoading) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}

		return Scaffold(
			appBar: AppBar(
				title: const Text('🍽️ Food Categories'),
				backgroundColor: Colors.orange.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: Column(
					children: [
						// Info card
						Card(
							margin: const EdgeInsets.all(16),
							color: Colors.blue.shade50,
							child: const Padding(
								padding: EdgeInsets.all(16),
								child: Row(
									children: [
										Icon(Icons.info, color: Colors.blue),
										SizedBox(width: 8),
										Expanded(
											child: Text(
												'Select the food categories you serve. This helps customers find your restaurant in the right category.',
												style: TextStyle(color: Colors.black87),
											),
										),
									],
								),
							),
						),

						// Categories selection
						Expanded(
							child: ListView.separated(
								padding: const EdgeInsets.symmetric(horizontal: 16),
								itemCount: _allFoodCategories.length,
								separatorBuilder: (context, index) => const SizedBox(height: 8),
								itemBuilder: (context, index) {
									final categoryKey = _allFoodCategories.keys.elementAt(index);
									final category = _allFoodCategories[categoryKey]!;
									final isSelected = _selectedCategories.contains(categoryKey);

									return Card(
										color: isSelected ? Colors.orange.shade50 : Colors.white,
										child: CheckboxListTile(
											value: isSelected,
											onChanged: (value) {
												setState(() {
													if (value == true) {
														_selectedCategories.add(categoryKey);
													} else {
														_selectedCategories.remove(categoryKey);
													}
												});
											},
											title: Row(
												children: [
													Text(category['emoji'], style: const TextStyle(fontSize: 24)),
													const SizedBox(width: 12),
													Text(
														category['name'],
														style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
													),
												],
											),
											subtitle: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(
														category['description'],
														style: const TextStyle(color: Colors.black54),
													),
													const SizedBox(height: 4),
													Wrap(
														spacing: 4,
														children: (category['examples'] as List<String>).map((example) => 
															Chip(
																label: Text(example, style: const TextStyle(fontSize: 10)),
																backgroundColor: Colors.grey.shade100,
																materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
															)
														).toList(),
													),
												],
											),
											activeColor: Colors.orange,
											isThreeLine: true,
										),
									);
								},
							),
						),

						// Save button
						Container(
							padding: const EdgeInsets.all(16),
							child: SizedBox(
								height: 56,
								width: double.infinity,
								child: FilledButton.icon(
									onPressed: _isSaving ? null : _saveCategories,
									icon: _isSaving 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.save),
									label: Text(_isSaving ? 'Saving...' : 'Save Categories'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.orange.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),
						),
					],
				),
			),
		);
	}
}