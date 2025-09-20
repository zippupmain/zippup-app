import 'package:flutter/material.dart';
import 'package:zippup/services/location/location_config_service.dart';
import 'package:zippup/services/currency/currency_service.dart';

/// Debug widget to show current location detection status
class LocationDebugWidget extends StatefulWidget {
  const LocationDebugWidget({super.key});

  @override
  State<LocationDebugWidget> createState() => _LocationDebugWidgetState();
}

class _LocationDebugWidgetState extends State<LocationDebugWidget> {
  Map<String, dynamic>? _config;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await LocationConfigService.getCurrentConfig();
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading config: $e');
    }
  }

  Future<void> _forceDetect() async {
    setState(() => _isLoading = true);
    try {
      await LocationConfigService.forceDetectCountry();
      await CurrencyService.refreshFromLocation();
      await _loadConfig();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error force detecting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Location Detection Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _forceDetect,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Force Detect Location',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_config != null) ...[
              _buildInfoRow('Country', '${_config!['countryName']} (${_config!['countryCode']})'),
              _buildInfoRow('Currency', '${_config!['currencySymbol']} ${_config!['currency']}'),
              _buildInfoRow('Address Bias', _config!['geocodingBias'] ?? 'None'),
              
              const SizedBox(height: 16),
              
              // Test currency display
              FutureBuilder<String>(
                future: CurrencyService.formatAmount(100.0),
                builder: (context, snapshot) {
                  return _buildInfoRow(
                    'Test Amount', 
                    snapshot.data ?? 'Loading...',
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Country selection
              const Text(
                'Manual Country Selection:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildCountryChip('NG', '🇳🇬 Nigeria'),
                  _buildCountryChip('US', '🇺🇸 USA'),
                  _buildCountryChip('GB', '🇬🇧 UK'),
                  _buildCountryChip('CA', '🇨🇦 Canada'),
                  _buildCountryChip('AU', '🇦🇺 Australia'),
                  _buildCountryChip('ZA', '🇿🇦 South Africa'),
                ],
              ),
            ] else ...[
              const Text('Loading location configuration...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryChip(String code, String label) {
    final isSelected = _config?['countryCode'] == code;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) async {
        if (selected) {
          setState(() => _isLoading = true);
          await LocationConfigService.setUserCountry(code);
          await CurrencyService.refreshFromLocation();
          await _loadConfig();
        }
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
    );
  }
}