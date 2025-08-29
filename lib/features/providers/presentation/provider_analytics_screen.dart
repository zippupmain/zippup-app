import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderAnalyticsScreen extends StatelessWidget {
	const ProviderAnalyticsScreen({super.key});
	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Analytics'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: FutureBuilder<Map<String, dynamic>>(
				future: _loadAnalytics(uid),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!;
					final double earnings = (data['earnings'] as num).toDouble();
					final int completed = (data['completed'] as num).toInt();
					final double rating = (data['rating'] as num).toDouble();
					final int totalRatings = (data['totalRatings'] as num).toInt();
					final Map<String, double> byCategory = Map<String, double>.from(data['byCategory'] as Map);
					return Padding(
						padding: const EdgeInsets.all(16),
						child: ListView(children: [
							Text('Completed: $completed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							const SizedBox(height: 8),
							Text('Total earnings: ${earnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							const SizedBox(height: 12),
							Text('Average rating: ${rating.toStringAsFixed(1)} (${totalRatings} ratings)', style: const TextStyle(fontSize: 16)),
							const SizedBox(height: 16),
							const Text('Earnings by category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
							const SizedBox(height: 8),
							...byCategory.entries.map((e) => ListTile(
								title: Text(e.key),
								trailing: Text(e.value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
							)),
						]),
					);
				},
			),
		);
	}

	Future<Map<String, dynamic>> _loadAnalytics(String uid) async {
		final ordersSnap = await FirebaseFirestore.instance
			.collection('orders')
			.where('providerId', isEqualTo: uid)
			.get(const GetOptions(source: Source.server));
		double earnings = 0;
		int completed = 0;
		final Map<String, double> byCategory = {};
		for (final d in ordersSnap.docs) {
			final m = d.data();
			final status = (m['status'] ?? '').toString();
			final price = (m['price'] as num?)?.toDouble() ?? 0;
			if (status == 'completed' || status == 'delivered') {
				completed++;
				earnings += price;
				final cat = (m['category'] ?? 'unknown').toString();
				byCategory[cat] = (byCategory[cat] ?? 0) + price;
			}
		}
		// ratings: aggregate across provider_profiles for this user
		double rating = 0;
		int totalRatings = 0;
		try {
			final profs = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.get(const GetOptions(source: Source.server));
			for (final p in profs.docs) {
				final r = (p.data()['rating'] as num?)?.toDouble() ?? 0.0;
				final n = (p.data()['totalRatings'] as num?)?.toInt() ?? 0;
				if (n > 0) {
					rating = (rating * totalRatings + r * n) / (totalRatings + n);
					totalRatings += n;
				}
			}
		} catch (_) {}
		return {
			'earnings': earnings,
			'completed': completed,
			'rating': rating,
			'totalRatings': totalRatings,
			'byCategory': byCategory,
		};
	}
}

