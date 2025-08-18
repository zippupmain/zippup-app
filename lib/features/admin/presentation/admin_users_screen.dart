import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _q = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search users', filled: true, border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12)))), onChanged: (_) => setState(() {})),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('name', descending: false).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) => (_q.text.trim().isEmpty) || (d.data()['name']?.toString().toLowerCase().contains(_q.text.trim().toLowerCase()) == true)).toList();
          if (docs.isEmpty) return const Center(child: Text('No users'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = docs[i].data();
              final id = docs[i].id;
              final disabled = u['disabled'] == true;
              return ListTile(
                title: Text(u['name']?.toString() ?? id),
                subtitle: Text(u['email']?.toString() ?? ''),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(value: !disabled, onChanged: (v) => FirebaseFirestore.instance.collection('users').doc(id).set({'disabled': !v}, SetOptions(merge: true))),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}