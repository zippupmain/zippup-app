class ChatMessage {
	final String id;
	final String senderId;
	final String text;
	final DateTime sentAt;

	const ChatMessage({required this.id, required this.senderId, required this.text, required this.sentAt});

	factory ChatMessage.fromJson(String id, Map<String, dynamic> json) => ChatMessage(
		id: id,
		senderId: json['senderId'] ?? '',
		text: json['text'] ?? '',
		sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
	);

	Map<String, dynamic> toJson() => {
		'senderId': senderId,
		'text': text,
		'sentAt': sentAt.toIso8601String(),
	};
}