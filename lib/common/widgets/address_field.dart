import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zippup/services/location/places_service.dart';

class AddressField extends StatefulWidget {
	final TextEditingController controller;
	final String label;
	final String? hint;
	final EdgeInsetsGeometry? contentPadding;
	const AddressField({super.key, required this.controller, required this.label, this.hint, this.contentPadding});

	@override
	State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
	final PlacesService _places = PlacesService();
	Timer? _debounce;
	List<PlacePrediction> _suggestions = const <PlacePrediction>[];
	bool _loading = false;

	void _onChanged(String value) {
		_debounce?.cancel();
		_debounce = Timer(const Duration(milliseconds: 350), () async {
			if (!mounted) return;
			if (value.trim().length < 3) {
				setState(() => _suggestions = const <PlacePrediction>[]);
				return;
			}
			setState(() => _loading = true);
			try {
				final results = await _places.autocomplete(value);
				if (!mounted) return;
				setState(() => _suggestions = results);
			} finally {
				if (mounted) setState(() => _loading = false);
			}
		});
	}

	@override
	void dispose() {
		_debounce?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				TextField(
					controller: widget.controller,
					decoration: InputDecoration(
						labelText: widget.label,
						hintText: widget.hint,
						contentPadding: widget.contentPadding,
						suffixIcon: _loading ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : const Icon(Icons.place_outlined),
					),
					onChanged: _onChanged,
				),
				if (_suggestions.isNotEmpty)
					Container(
						margin: const EdgeInsets.only(top: 4),
						constraints: const BoxConstraints(maxHeight: 200),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(8),
							boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
							border: Border.all(color: Colors.black12),
						),
						child: ListView.separated(
							shrinkWrap: true,
							itemBuilder: (context, i) {
								final p = _suggestions[i];
								return ListTile(
									dense: true,
									title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
									onTap: () {
									widget.controller.text = p.description;
									setState(() => _suggestions = const <PlacePrediction>[]);
								},
								);
							},
							separatorBuilder: (_, __) => const Divider(height: 1),
							itemCount: _suggestions.length,
						),
					),
			],
		);
	}
}