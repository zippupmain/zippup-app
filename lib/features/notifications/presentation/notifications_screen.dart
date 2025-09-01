import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No notifications'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final n = d.data();
              final unread = n['read'] != true;
              final title = n['title']?.toString() ?? 'Notification';
              final body = n['body']?.toString() ?? '';
              return ListTile(
                title: Text(title, style: TextStyle(fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(body),
                trailing: unread ? const Icon(Icons.brightness_1, color: Colors.red, size: 10) : null,
                onTap: () async {
                  await d.reference.set({'read': true}, SetOptions(merge: true));
                  final route = n['route']?.toString();
                  if (route != null && route.isNotEmpty && context.mounted) {
                    context.push(route);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

