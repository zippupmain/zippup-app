import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:zippup/core/config/country_config_service.dart';

class DataScreen extends StatefulWidget {
	const DataScreen({super.key});

	@override
	State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
	final _formKey = GlobalKey<FormState>();
	final _phone = TextEditingController();
	final _amount = TextEditingController();
	final _bundleCode = TextEditingController();
	bool _loading = false;

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _loading = true);
		try {
			final cc = await CountryConfigService.instance.getCountryCode();
			final currency = await CountryConfigService.instance.getCurrencyCode();
			final fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('dataPurchase');
			await fn.call({
				'phone': _phone.text.trim(),
				'bundleCode': _bundleCode.text.trim(),
				'amount': double.parse(_amount.text.trim()),
				'country': cc,
				'currency': currency,
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data bundle purchase initiated')));
			Navigator.pop(context);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Buy Data')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Form(
					key: _formKey,
					child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						TextFormField(
							controller: _phone,
							keyboardType: TextInputType.phone,
							decoration: const InputDecoration(labelText: 'Phone number'),
							validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
						),
						const SizedBox(height: 12),
						TextFormField(
							controller: _bundleCode,
							decoration: const InputDecoration(labelText: 'Bundle code (e.g. 1GB_30D)'),
							validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
						),
						const SizedBox(height: 12),
						TextFormField(
							controller: _amount,
							keyboardType: TextInputType.number,
							decoration: const InputDecoration(labelText: 'Amount'),
							validator: (v) => ((double.tryParse(v?.trim() ?? '') ?? 0) <= 0) ? 'Enter amount' : null,
						),
						const Spacer(),
						SizedBox(
							width: double.infinity,
							child: FilledButton(
								onPressed: _loading ? null : _submit,
								child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Buy'),
							),
						),
					]),
				),
			),
		);
	}
}

