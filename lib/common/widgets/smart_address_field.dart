import 'package:flutter/material.dart';
import 'package:zippup/services/location/address_suggestion_service.dart';
import 'package:zippup/services/location/global_location_bias_service.dart';
import 'dart:async';

/// Smart address input field with location-biased suggestions and place name search
class SmartAddressField extends StatefulWidget {
  final String? initialValue;
  final String hintText;
  final IconData? prefixIcon;
  final Function(Map<String, dynamic>) onAddressSelected;
  final bool allowPlaceNames;

  const SmartAddressField({
    super.key,
    this.initialValue,
    this.hintText = 'Enter address or place name',
    this.prefixIcon,
    required this.onAddressSelected,
    this.allowPlaceNames = true,
  });

  @override
  State<SmartAddressField> createState() => _SmartAddressFieldState();
}

class _SmartAddressFieldState extends State<SmartAddressField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchAddresses(query);
      } else {
        _clearSuggestions();
      }
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_controller.text.trim().isNotEmpty) {
        _searchAddresses(_controller.text.trim());
      }
    } else {
      _removeOverlay();
    }
  }

  Future<void> _searchAddresses(String query) async {
    setState(() => _isLoading = true);
    
    try {
      // Use global location bias for ALL address searches
      final results = await GlobalLocationBiasService.getBiasedAddressSuggestions(query);
      
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      print('❌ Error searching addresses with global bias: $e');
      // Fallback to original service
      try {
        final results = await AddressSuggestionService.universalSearch(query);
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      } catch (fallbackError) {
        setState(() => _isLoading = false);
        _removeOverlay();
      }
    }
  }

  void _clearSuggestions() {
    setState(() => _suggestions = []);
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getTextFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  final isPlace = suggestion['name'] != null;
                  
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isPlace ? Icons.place : Icons.location_on,
                      color: isPlace ? Colors.blue : Colors.green,
                      size: 20,
                    ),
                    title: Text(
                      isPlace ? suggestion['name'] : suggestion['address'],
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: isPlace 
                        ? Text(
                            suggestion['address'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: isPlace 
                        ? const Icon(Icons.business, size: 16, color: Colors.grey)
                        : const Icon(Icons.home, size: 16, color: Colors.grey),
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final address = suggestion['name'] ?? suggestion['address'] ?? '';
    _controller.text = address;
    _removeOverlay();
    _focusNode.unfocus();
    
    // Save address for future use
    AddressSuggestionService.saveAddress(suggestion);
    
    // Notify parent
    widget.onAddressSelected(suggestion);
  }

  double _getTextFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
          suffixIcon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _controller.clear();
                        _clearSuggestions();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _searchAddresses(value.trim());
          }
        },
      ),
    );
  }
}