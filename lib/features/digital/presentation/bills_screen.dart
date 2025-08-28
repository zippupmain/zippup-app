import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:zippup/core/config/country_config_service.dart';

class BillsScreen extends StatefulWidget {
	const BillsScreen({super.key});

	@override
	State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
	final _formKey = GlobalKey<FormState>();
	final _billerCode = TextEditingController();
	final _account = TextEditingController();
	final _amount = TextEditingController();
	bool _loading = false;

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _loading = true);
		try {
			final cc = await CountryConfigService.instance.getCountryCode();
			final currency = await CountryConfigService.instance.getCurrencyCode();
			final fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('billPay');
			await fn.call({
				'billerCode': _billerCode.text.trim(),
				'account': _account.text.trim(),
				'amount': double.parse(_amount.text.trim()),
				'country': cc,
				'currency': currency,
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill payment initiated')));
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
			appBar: AppBar(title: const Text('Pay Bills')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Form(
					key: _formKey,
					child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						TextFormField(
							controller: _billerCode,
							decoration: const InputDecoration(labelText: 'Biller code (e.g. ELECTRIC_PREPAID)'),
							validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
						),
						const SizedBox(height: 12),
						TextFormField(
							controller: _account,
							decoration: const InputDecoration(labelText: 'Account / Meter / Customer Ref'),
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
								child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Pay'),
							),
						),
					]),
				),
			),
		);
	}
}

