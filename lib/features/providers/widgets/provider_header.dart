import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderHeader extends StatefulWidget {
	final String service;
	const ProviderHeader({super.key, required this.service});
	@override
	State<ProviderHeader> createState() => _ProviderHeaderState();
}

class _ProviderHeaderState extends State<ProviderHeader> {
	String? _title;
	String? _bannerUrl;
	String? _publicImageUrl;
	bool _loaded = false;

	@override
	void initState() {
		super.initState();
		_fetch();
	}

	Future<void> _fetch() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;
			final snap = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: widget.service)
				.limit(1)
				.get(const GetOptions(source: Source.server));
			if (snap.docs.isNotEmpty) {
				final meta = (snap.docs.first.data()['metadata'] as Map<String, dynamic>? ?? {});
				setState(() {
					_title = (meta['title'] ?? '').toString();
					_bannerUrl = (meta['bannerUrl'] ?? '').toString();
					_publicImageUrl = (meta['publicImageUrl'] ?? '').toString();
					_loaded = true;
				});
			} else {
				setState(() => _loaded = true);
			}
		} catch (_) {
			setState(() => _loaded = true);
		}
	}

	@override
	Widget build(BuildContext context) {
		final height = 140.0;
		return SizedBox(
			height: height,
			child: Stack(children: [
				Positioned.fill(
					child: _bannerUrl != null && _bannerUrl!.isNotEmpty
						? Image.network(_bannerUrl!, fit: BoxFit.cover)
						: Container(color: Colors.grey.shade200),
				),
				Positioned(
					left: 12,
					bottom: 12,
					child: Row(children: [
						CircleAvatar(
							radius: 24,
							backgroundImage: (_publicImageUrl != null && _publicImageUrl!.isNotEmpty) ? NetworkImage(_publicImageUrl!) : null,
							child: (_publicImageUrl == null || _publicImageUrl!.isEmpty) ? const Icon(Icons.business) : null,
						),
						const SizedBox(width: 12),
						Text(_title?.isNotEmpty == true ? _title! : 'My business', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
					]),
				),
				if (!_loaded)
					Positioned.fill(child: Container(color: Colors.black12))
			]),
		);
	}
}