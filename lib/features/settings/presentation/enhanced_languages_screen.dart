import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/localization/app_localizations.dart';

class EnhancedLanguagesScreen extends StatefulWidget {
	const EnhancedLanguagesScreen({super.key});

	@override
	State<EnhancedLanguagesScreen> createState() => _EnhancedLanguagesScreenState();
}

class _EnhancedLanguagesScreenState extends State<EnhancedLanguagesScreen> {
	String _selectedLanguage = 'en';
	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';

	final List<Map<String, dynamic>> _languages = [
		// Major Global Languages
		{'code': 'en', 'name': 'English', 'nativeName': 'English', 'flag': '🇺🇸', 'region': 'Global'},
		{'code': 'es', 'name': 'Spanish', 'nativeName': 'Español', 'flag': '🇪🇸', 'region': 'Global'},
		{'code': 'fr', 'name': 'French', 'nativeName': 'Français', 'flag': '🇫🇷', 'region': 'Global'},
		{'code': 'de', 'name': 'German', 'nativeName': 'Deutsch', 'flag': '🇩🇪', 'region': 'Europe'},
		{'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português', 'flag': '🇧🇷', 'region': 'Americas'},
		{'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية', 'flag': '🇸🇦', 'region': 'Middle East'},
		{'code': 'zh', 'name': 'Chinese', 'nativeName': '中文', 'flag': '🇨🇳', 'region': 'Asia'},
		{'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी', 'flag': '🇮🇳', 'region': 'Asia'},
		{'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語', 'flag': '🇯🇵', 'region': 'Asia'},
		{'code': 'ko', 'name': 'Korean', 'nativeName': '한국어', 'flag': '🇰🇷', 'region': 'Asia'},
		{'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский', 'flag': '🇷🇺', 'region': 'Europe'},
		{'code': 'it', 'name': 'Italian', 'nativeName': 'Italiano', 'flag': '🇮🇹', 'region': 'Europe'},
		{'code': 'nl', 'name': 'Dutch', 'nativeName': 'Nederlands', 'flag': '🇳🇱', 'region': 'Europe'},
		{'code': 'sv', 'name': 'Swedish', 'nativeName': 'Svenska', 'flag': '🇸🇪', 'region': 'Europe'},
		{'code': 'da', 'name': 'Danish', 'nativeName': 'Dansk', 'flag': '🇩🇰', 'region': 'Europe'},
		{'code': 'no', 'name': 'Norwegian', 'nativeName': 'Norsk', 'flag': '🇳🇴', 'region': 'Europe'},
		{'code': 'fi', 'name': 'Finnish', 'nativeName': 'Suomi', 'flag': '🇫🇮', 'region': 'Europe'},
		{'code': 'pl', 'name': 'Polish', 'nativeName': 'Polski', 'flag': '🇵🇱', 'region': 'Europe'},
		{'code': 'tr', 'name': 'Turkish', 'nativeName': 'Türkçe', 'flag': '🇹🇷', 'region': 'Europe'},
		{'code': 'th', 'name': 'Thai', 'nativeName': 'ไทย', 'flag': '🇹🇭', 'region': 'Asia'},
		{'code': 'vi', 'name': 'Vietnamese', 'nativeName': 'Tiếng Việt', 'flag': '🇻🇳', 'region': 'Asia'},
		{'code': 'id', 'name': 'Indonesian', 'nativeName': 'Bahasa Indonesia', 'flag': '🇮🇩', 'region': 'Asia'},
		{'code': 'ms', 'name': 'Malay', 'nativeName': 'Bahasa Melayu', 'flag': '🇲🇾', 'region': 'Asia'},
		{'code': 'tl', 'name': 'Filipino', 'nativeName': 'Filipino', 'flag': '🇵🇭', 'region': 'Asia'},
		
		// African Languages
		{'code': 'sw', 'name': 'Swahili', 'nativeName': 'Kiswahili', 'flag': '🇰🇪', 'region': 'Africa'},
		{'code': 'am', 'name': 'Amharic', 'nativeName': 'አማርኛ', 'flag': '🇪🇹', 'region': 'Africa'},
		{'code': 'ha', 'name': 'Hausa', 'nativeName': 'Hausa', 'flag': '🇳🇬', 'region': 'Africa'},
		{'code': 'yo', 'name': 'Yoruba', 'nativeName': 'Yorùbá', 'flag': '🇳🇬', 'region': 'Africa'},
		{'code': 'ig', 'name': 'Igbo', 'nativeName': 'Igbo', 'flag': '🇳🇬', 'region': 'Africa'},
	];

	@override
	void initState() {
		super.initState();
		_loadSavedLanguage();
	}

	Future<void> _loadSavedLanguage() async {
		final savedLanguage = await AppLocalizations.getSavedLanguage();
		setState(() => _selectedLanguage = savedLanguage);
	}

	List<Map<String, dynamic>> get _filteredLanguages {
		if (_searchQuery.isEmpty) return _languages;
		return _languages.where((lang) {
			final name = lang['name'].toString().toLowerCase();
			final nativeName = lang['nativeName'].toString().toLowerCase();
			final query = _searchQuery.toLowerCase();
			return name.contains(query) || nativeName.contains(query);
		}).toList();
	}

	Map<String, List<Map<String, dynamic>>> get _groupedLanguages {
		final grouped = <String, List<Map<String, dynamic>>>{};
		for (final lang in _filteredLanguages) {
			final region = lang['region'] as String;
			grouped.putIfAbsent(region, () => []).add(lang);
		}
		return grouped;
	}

	Future<void> _saveLanguage(String languageCode) async {
		setState(() => _selectedLanguage = languageCode);
		
		try {
			// Save to local storage
			await AppLocalizations.saveLanguage(languageCode);
			
			// Save to Firestore for user profile
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				await FirebaseFirestore.instance
					.collection('users')
					.doc(uid)
					.update({'language': languageCode});
			}

			if (mounted) {
				final language = _languages.firstWhere((l) => l['code'] == languageCode);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('✅ Language set to ${language['name']}'),
						backgroundColor: Colors.green,
					)
				);
				
				// Show restart message for full effect
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('🌍 Language Changed'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Language changed to ${language['name']} (${language['nativeName']})'),
								const SizedBox(height: 12),
								const Text(
									'For best experience, restart the app to see all text in the new language.',
									style: TextStyle(color: Colors.grey),
								),
							],
						),
						actions: [
							TextButton(
								onPressed: () {
									Navigator.pop(context);
									context.pop();
								},
								child: const Text('OK'),
							),
						],
					),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed to save language: $e'))
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🌍 Languages'),
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
									labelText: 'Search languages...',
									labelStyle: const TextStyle(color: Colors.black),
									hintText: 'English, Spanish, Arabic...',
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
										Icon(Icons.public, color: Colors.green),
										SizedBox(width: 8),
										Expanded(
											child: Text(
												'ZippUp supports 30+ languages for truly global reach. Select your preferred language below.',
												style: TextStyle(color: Colors.black87, fontSize: 14),
											),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Languages list by region
						Expanded(
							child: ListView(
								padding: const EdgeInsets.symmetric(horizontal: 16),
								children: _groupedLanguages.entries.map((entry) {
									final region = entry.key;
									final languages = entry.value;
									
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
											...languages.map((language) {
												final isSelected = _selectedLanguage == language['code'];
												return Card(
													color: isSelected ? Colors.blue.shade50 : Colors.white,
													child: ListTile(
														leading: Text(
															language['flag'],
															style: const TextStyle(fontSize: 28),
														),
														title: Text(
															language['name'],
															style: TextStyle(
																fontWeight: FontWeight.bold,
																color: isSelected ? Colors.blue.shade700 : Colors.black,
															),
														),
														subtitle: Text(
															language['nativeName'],
															style: const TextStyle(color: Colors.black54),
														),
														trailing: isSelected 
															? const Icon(Icons.check_circle, color: Colors.green)
															: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
														onTap: () => _saveLanguage(language['code']),
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