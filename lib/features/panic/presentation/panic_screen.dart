import 'package:flutter/material.dart';

class PanicScreen extends StatelessWidget {
  const PanicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panic Mode')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send Alert'),
          onPressed: () async {
            final shouldSend = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Emergency Alert'),
                content: const Text(
                  'Send your live location to your emergency contacts?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
            if (shouldSend == true) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency alert sent')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
