import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zippup/services/location/places_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
	stt.SpeechToText? _speech;
	bool _listening = false;

	@override
	void initState() {
		super.initState();
		if (!kIsWeb) {
			_speech = stt.SpeechToText();
		}
	}

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
						suffixIcon: _loading
							? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
							: SizedBox(
								width: 72,
								child: Row(mainAxisSize: MainAxisSize.min, children: [
									IconButton(
										tooltip: _listening ? 'Stop' : 'Voice input',
										onPressed: kIsWeb ? null : () async {
											if (_speech == null) return;
											if (_listening) {
												await _speech!.stop();
												setState(() => _listening = false);
												return;
											}
											final ok = await _speech!.initialize(onStatus: (_) {}, onError: (_) {});
											if (!ok) return;
											setState(() => _listening = true);
											_speech!.listen(onResult: (r) {
												widget.controller.text = r.recognizedWords;
												widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: widget.controller.text.length));
											});
										},
										icon: Icon(_listening ? Icons.stop : Icons.mic_none_rounded),
									),
									const Icon(Icons.place_outlined),
								]),
							),
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