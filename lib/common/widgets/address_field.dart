import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zippup/services/location/places_service.dart';
import 'package:zippup/services/location/global_location_bias_service.dart';
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
		// Initialize speech for all platforms
		_speech = stt.SpeechToText();
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
					style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
					decoration: InputDecoration(
						labelText: widget.label,
						labelStyle: const TextStyle(color: Colors.black87),
						hintText: widget.hint,
						hintStyle: const TextStyle(color: Colors.black54),
						contentPadding: widget.contentPadding,
						filled: true,
						fillColor: Colors.white,
						border: OutlineInputBorder(
							borderRadius: BorderRadius.circular(12),
							borderSide: const BorderSide(color: Colors.black26),
						),
						enabledBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(12),
							borderSide: const BorderSide(color: Colors.black26),
						),
						focusedBorder: OutlineInputBorder(
							borderRadius: BorderRadius.circular(12),
							borderSide: const BorderSide(color: Colors.blue, width: 2),
						),
						suffixIcon: _loading
							? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
							: SizedBox(
								width: 72,
								child: Row(mainAxisSize: MainAxisSize.min, children: [
									Container(
										decoration: BoxDecoration(
											color: _listening ? Colors.red.shade100 : Colors.blue.shade100,
											shape: BoxShape.circle,
										),
										child: IconButton(
											tooltip: _listening ? 'Stop voice input' : 'Voice input for address',
											onPressed: () async {
												print('🎤 Address voice search pressed, listening: $_listening');
												
												if (_speech == null) {
													print('❌ Speech service not initialized');
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Voice input not available')),
													);
													return;
												}
												
												if (_listening) {
													await _speech!.stop();
													setState(() => _listening = false);
													print('🛑 Address voice input stopped');
													return;
												}
												
												try {
													print('🔄 Initializing address voice input...');
													final available = await _speech!.initialize(
														onStatus: (status) {
															print('🎤 Address speech status: $status');
														}, 
														onError: (error) {
															print('❌ Address speech error: $error');
															if (mounted) {
																setState(() => _listening = false);
																ScaffoldMessenger.of(context).showSnackBar(
																	SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
																);
															}
														}
													);
													
													if (!available) {
														print('❌ Speech recognition not available');
														ScaffoldMessenger.of(context).showSnackBar(
															const SnackBar(content: Text('Voice input not available on this device')),
														);
														return;
													}
													
													print('✅ Address speech initialized, listening...');
													setState(() => _listening = true);
													
													_speech!.listen(
														onResult: (result) {
															print('🎤 Address speech result: ${result.recognizedWords} (final: ${result.finalResult})');
															
															// Only update on final result to avoid duplicates
															if (result.finalResult) {
																final newText = result.recognizedWords.trim();
																if (newText.isNotEmpty && newText != widget.controller.text) {
																	widget.controller.text = newText;
																	widget.controller.selection = TextSelection.fromPosition(
																		TextPosition(offset: widget.controller.text.length)
																	);
																}
															}
														},
														listenFor: const Duration(seconds: 30),
														pauseFor: const Duration(seconds: 3),
													);
												} catch (e) {
													print('❌ Address speech failed: $e');
													ScaffoldMessenger.of(context).showSnackBar(
														SnackBar(content: Text('Voice input failed: $e')),
													);
												}
											},
											icon: Icon(
												_listening ? Icons.stop : Icons.mic,
												color: _listening ? Colors.red.shade700 : Colors.blue.shade700,
												size: 20,
											),
										),
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
									title: Text(
										p.description, 
										maxLines: 2, 
										overflow: TextOverflow.ellipsis,
										style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
									),
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