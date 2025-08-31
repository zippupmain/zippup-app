import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class CountrySelectionScreen extends StatefulWidget {
	const CountrySelectionScreen({super.key});

	@override
	State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';
	String? _selectedCountry;

	final List<Map<String, dynamic>> _countries = [
		// Africa (Primary Markets)
		{'code': 'NG', 'name': 'Nigeria', 'flag': '🇳🇬', 'currency': 'NGN (₦)', 'region': 'Africa'},
		{'code': 'KE', 'name': 'Kenya', 'flag': '🇰🇪', 'currency': 'KES (KSh)', 'region': 'Africa'},
		{'code': 'GH', 'name': 'Ghana', 'flag': '🇬🇭', 'currency': 'GHS (₵)', 'region': 'Africa'},
		{'code': 'ZA', 'name': 'South Africa', 'flag': '🇿🇦', 'currency': 'ZAR (R)', 'region': 'Africa'},
		{'code': 'UG', 'name': 'Uganda', 'flag': '🇺🇬', 'currency': 'UGX (USh)', 'region': 'Africa'},
		{'code': 'TZ', 'name': 'Tanzania', 'flag': '🇹🇿', 'currency': 'TZS (TSh)', 'region': 'Africa'},
		{'code': 'RW', 'name': 'Rwanda', 'flag': '🇷🇼', 'currency': 'RWF (RF)', 'region': 'Africa'},
		
		// Americas
		{'code': 'US', 'name': 'United States', 'flag': '🇺🇸', 'currency': 'USD (\$)', 'region': 'Americas'},
		{'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦', 'currency': 'CAD (C\$)', 'region': 'Americas'},
		{'code': 'BR', 'name': 'Brazil', 'flag': '🇧🇷', 'currency': 'BRL (R\$)', 'region': 'Americas'},
		{'code': 'MX', 'name': 'Mexico', 'flag': '🇲🇽', 'currency': 'MXN (\$)', 'region': 'Americas'},
		
		// Europe
		{'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧', 'currency': 'GBP (£)', 'region': 'Europe'},
		{'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪', 'currency': 'EUR (€)', 'region': 'Europe'},
		{'code': 'FR', 'name': 'France', 'flag': '🇫🇷', 'currency': 'EUR (€)', 'region': 'Europe'},
		{'code': 'ES', 'name': 'Spain', 'flag': '🇪🇸', 'currency': 'EUR (€)', 'region': 'Europe'},
		{'code': 'IT', 'name': 'Italy', 'flag': '🇮🇹', 'currency': 'EUR (€)', 'region': 'Europe'},
		
		// Asia
		{'code': 'IN', 'name': 'India', 'flag': '🇮🇳', 'currency': 'INR (₹)', 'region': 'Asia'},
		{'code': 'PH', 'name': 'Philippines', 'flag': '🇵🇭', 'currency': 'PHP (₱)', 'region': 'Asia'},
		{'code': 'ID', 'name': 'Indonesia', 'flag': '🇮🇩', 'currency': 'IDR (Rp)', 'region': 'Asia'},
		{'code': 'TH', 'name': 'Thailand', 'flag': '🇹🇭', 'currency': 'THB (฿)', 'region': 'Asia'},
		{'code': 'MY', 'name': 'Malaysia', 'flag': '🇲🇾', 'currency': 'MYR (RM)', 'region': 'Asia'},
	];

	List<Map<String, dynamic>> get _filteredCountries {
		if (_searchQuery.isEmpty) return _countries;
		return _countries.where((country) {
			final name = country['name'].toString().toLowerCase();
			final code = country['code'].toString().toLowerCase();
			final query = _searchQuery.toLowerCase();
			return name.contains(query) || code.contains(query);
		}).toList();
	}

	Map<String, List<Map<String, dynamic>>> get _groupedCountries {
		final grouped = <String, List<Map<String, dynamic>>>{};
		for (final country in _filteredCountries) {
			final region = country['region'] as String;
			grouped.putIfAbsent(region, () => []).add(country);
		}
		return grouped;
	}

	Future<void> _selectCountry(String countryCode) async {
		setState(() => _selectedCountry = countryCode);
		
		// Save to preferences using the service
		await CountryDetectionService.saveCountrySelection(countryCode);
		
		// Show confirmation
		if (mounted) {
			final country = _countries.firstWhere((c) => c['code'] == countryCode);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ Country set to ${country['name']}'),
					backgroundColor: Colors.green,
				)
			);
			
			// Navigate back
			Future.delayed(const Duration(seconds: 1), () {
				if (mounted) context.pop();
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🌍 Select Country'),
				backgroundColor: Colors.blue.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: Column(
					children: [
						// Search bar
						Container(
							color: Colors.white,
							padding: const EdgeInsets.all(16),
							child: TextField(
								controller: _searchController,
								style: const TextStyle(color: Colors.black),
								decoration: InputDecoration(
									labelText: 'Search countries...',
									labelStyle: const TextStyle(color: Colors.black),
									hintText: 'Nigeria, Kenya, USA...',
									hintStyle: const TextStyle(color: Colors.black38),
									prefixIcon: const Icon(Icons.search, color: Colors.blue),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
									),
									focusedBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: const BorderSide(color: Colors.blue, width: 2),
									),
									filled: true,
									fillColor: Colors.blue.shade50,
								),
								onChanged: (value) {
									setState(() => _searchQuery = value);
								},
							),
						),

						// Info card
						Card(
							margin: const EdgeInsets.symmetric(horizontal: 16),
							color: Colors.green.shade50,
							child: const Padding(
								padding: EdgeInsets.all(16),
								child: Row(
									children: [
										Icon(Icons.info, color: Colors.green),
										SizedBox(width: 8),
										Expanded(
											child: Text(
												'Digital services (airtime, data, bills) will be customized for your selected country.',
												style: TextStyle(color: Colors.black87, fontSize: 14),
											),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Countries list by region
						Expanded(
							child: ListView(
								padding: const EdgeInsets.symmetric(horizontal: 16),
								children: _groupedCountries.entries.map((entry) {
									final region = entry.key;
									final countries = entry.value;
									
									return Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Padding(
												padding: const EdgeInsets.symmetric(vertical: 8),
												child: Text(
													region,
													style: TextStyle(
														fontSize: 18,
														fontWeight: FontWeight.bold,
														color: Colors.grey.shade700,
													),
												),
											),
											...countries.map((country) {
												final isSelected = _selectedCountry == country['code'];
												return Card(
													color: isSelected ? Colors.blue.shade50 : Colors.white,
													child: ListTile(
														leading: Text(
															country['flag'],
															style: const TextStyle(fontSize: 32),
														),
														title: Text(
															country['name'],
															style: TextStyle(
																fontWeight: FontWeight.bold,
																color: isSelected ? Colors.blue.shade700 : Colors.black,
															),
														),
														subtitle: Text(
															'${country['code']} • ${country['currency']}',
															style: const TextStyle(color: Colors.black54),
														),
														trailing: isSelected 
															? const Icon(Icons.check_circle, color: Colors.green)
															: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
														onTap: () => _selectCountry(country['code']),
													),
												);
											}).toList(),
											const SizedBox(height: 16),
										],
									);
								}).toList(),
							),
						),
					],
				),
			),
		);
	}
}