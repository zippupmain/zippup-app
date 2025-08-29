import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/chat_message.dart';
import 'package:zippup/features/calls/services/call_service.dart';

class ChatScreen extends StatefulWidget {
	const ChatScreen({super.key, required this.threadId, required this.title});
	final String threadId;
	final String title;
	@override
	State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
	final _text = TextEditingController();
	final _callService = CallService();
	String? _callId;

	Future<void> _startCall() async {
		// In a real app, resolve the other party id from the thread document
		final thread = await FirebaseFirestore.instance.collection('chats').doc(widget.threadId).get();
		final participants = (thread.data()?['participants'] as List?)?.cast<String>() ?? const <String>[];
		final myId = FirebaseAuth.instance.currentUser?.uid;
		final calleeId = participants.firstWhere((p) => p != myId, orElse: () => '');
		if (calleeId.isEmpty) return;
		final id = await _callService.startCall(calleeId: calleeId, threadId: widget.threadId);
		setState(() => _callId = id);
		if (!mounted) return;
		showDialog(context: context, barrierDismissible: false, builder: (_) => _CallDialog(callId: id, callService: _callService));
	}

	Stream<List<ChatMessage>> _stream() {
		return FirebaseFirestore.instance
			.collection('chats')
			.doc(widget.threadId)
			.collection('messages')
			.orderBy('sentAt', descending: true)
			.snapshots()
			.map((snap) => snap.docs.map((d) => ChatMessage.fromJson(d.id, d.data())).toList());
	}

	Future<void> _send() async {
		final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
		final text = _text.text.trim();
		if (text.isEmpty) return;
		await FirebaseFirestore.instance.collection('chats').doc(widget.threadId).collection('messages').add({
			'senderId': userId,
			'text': text,
			'sentAt': DateTime.now().toIso8601String(),
		});
		_text.clear();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: _startCall, icon: const Icon(Icons.call))]),
			body: Column(
				children: [
					Expanded(
						child: StreamBuilder<List<ChatMessage>>(
							stream: _stream(),
							builder: (context, snapshot) {
								final msgs = snapshot.data ?? const <ChatMessage>[];
								return ListView.builder(
									reverse: true,
									itemCount: msgs.length,
									itemBuilder: (context, i) {
										final m = msgs[i];
										final mine = m.senderId == FirebaseAuth.instance.currentUser?.uid;
										return Align(
											alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
											child: Container(
												margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
												padding: const EdgeInsets.all(12),
												decoration: BoxDecoration(color: mine ? Colors.blue.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
												child: Text(m.text),
											),
										);
									},
								);
							},
						),
					),
					Row(
						children: [
							Expanded(
								child: Padding(
									padding: const EdgeInsets.all(8.0),
									child: TextField(controller: _text, decoration: const InputDecoration(hintText: 'Type a message', border: OutlineInputBorder())),
								),
							),
							IconButton(onPressed: _send, icon: const Icon(Icons.send)),
						],
					),
				],
			),
		);
	}
}

class _CallDialog extends StatefulWidget {
	const _CallDialog({required this.callId, required this.callService});
	final String callId;
	final CallService callService;
	@override
	State<_CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<_CallDialog> {
	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text('In-app call'),
			content: const Text('Ringing...'),
			actions: [
				TextButton(onPressed: () { widget.callService.busy(callId: widget.callId); Navigator.pop(context); }, child: const Text('Busy')),
				TextButton(onPressed: () { widget.callService.decline(callId: widget.callId); Navigator.pop(context); }, child: const Text('Decline')),
				FilledButton(onPressed: () { widget.callService.accept(callId: widget.callId); Navigator.pop(context); }, child: const Text('Accept')),
			],
		);
	}
}