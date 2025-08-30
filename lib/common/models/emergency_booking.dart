import 'package:equatable/equatable.dart';

enum EmergencyType { medical, security, fire, technical, roadside }

enum EmergencyStatus { requested, accepted, arriving, arrived, inProgress, completed, cancelled }

enum EmergencyPriority { low, medium, high, critical }

class EmergencyBooking extends Equatable {
	final String id;
	final String clientId;
	final String? providerId;
	final EmergencyType type;
	final String description;
	final EmergencyPriority priority;
	final String emergencyAddress;
	final DateTime createdAt;
	final double feeEstimate;
	final int etaMinutes;
	final EmergencyStatus status;
	final String? paymentMethod;

	const EmergencyBooking({
		required this.id,
		required this.clientId,
		this.providerId,
		required this.type,
		required this.description,
		required this.priority,
		required this.emergencyAddress,
		required this.createdAt,
		required this.feeEstimate,
		required this.etaMinutes,
		required this.status,
		this.paymentMethod,
	});

	factory EmergencyBooking.fromJson(String id, Map<String, dynamic> json) => EmergencyBooking(
		id: id,
		clientId: json['clientId'] ?? '',
		providerId: json['providerId'],
		type: EmergencyType.values.firstWhere((e) => e.name == (json['type'] ?? 'medical'), orElse: () => EmergencyType.medical),
		description: json['description'] ?? '',
		priority: EmergencyPriority.values.firstWhere((e) => e.name == (json['priority'] ?? 'medium'), orElse: () => EmergencyPriority.medium),
		emergencyAddress: json['emergencyAddress'] ?? '',
		createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
		feeEstimate: (json['feeEstimate'] is num) ? (json['feeEstimate'] as num).toDouble() : 0,
		etaMinutes: (json['etaMinutes'] is num) ? (json['etaMinutes'] as num).toInt() : 0,
		status: EmergencyStatus.values.firstWhere((e) => e.name == (json['status'] ?? 'requested'), orElse: () => EmergencyStatus.requested),
		paymentMethod: json['paymentMethod'],
	);

	Map<String, dynamic> toJson() => {
		'clientId': clientId,
		'providerId': providerId,
		'type': type.name,
		'description': description,
		'priority': priority.name,
		'emergencyAddress': emergencyAddress,
		'createdAt': createdAt.toIso8601String(),
		'feeEstimate': feeEstimate,
		'etaMinutes': etaMinutes,
		'status': status.name,
		'paymentMethod': paymentMethod,
	};

	@override
	List<Object?> get props => [id, status, type, clientId, providerId, priority];
}