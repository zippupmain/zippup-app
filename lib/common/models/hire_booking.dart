import 'package:equatable/equatable.dart';

enum HireType { home, tech, construction, auto, personal }

enum HireStatus { requested, accepted, arriving, arrived, inProgress, completed, cancelled }

class HireBooking extends Equatable {
	final String id;
	final String clientId;
	final String? providerId;
	final HireType type;
	final String serviceCategory;
	final String description;
	final bool isScheduled;
	final DateTime? scheduledAt;
	final String serviceAddress;
	final DateTime createdAt;
	final double feeEstimate;
	final int etaMinutes;
	final HireStatus status;
	final String? paymentMethod;

	const HireBooking({
		required this.id,
		required this.clientId,
		this.providerId,
		required this.type,
		required this.serviceCategory,
		required this.description,
		required this.isScheduled,
		this.scheduledAt,
		required this.serviceAddress,
		required this.createdAt,
		required this.feeEstimate,
		required this.etaMinutes,
		required this.status,
		this.paymentMethod,
	});

	factory HireBooking.fromJson(String id, Map<String, dynamic> json) => HireBooking(
		id: id,
		clientId: json['clientId'] ?? '',
		providerId: json['providerId'],
		type: HireType.values.firstWhere((e) => e.name == (json['type'] ?? 'home'), orElse: () => HireType.home),
		serviceCategory: json['serviceCategory'] ?? '',
		description: json['description'] ?? '',
		isScheduled: json['isScheduled'] == true,
		scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null,
		serviceAddress: json['serviceAddress'] ?? '',
		createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
		feeEstimate: (json['feeEstimate'] is num) ? (json['feeEstimate'] as num).toDouble() : 0,
		etaMinutes: (json['etaMinutes'] is num) ? (json['etaMinutes'] as num).toInt() : 0,
		status: HireStatus.values.firstWhere((e) => e.name == (json['status'] ?? 'requested'), orElse: () => HireStatus.requested),
		paymentMethod: json['paymentMethod'],
	);

	Map<String, dynamic> toJson() => {
		'clientId': clientId,
		'providerId': providerId,
		'type': type.name,
		'serviceCategory': serviceCategory,
		'description': description,
		'isScheduled': isScheduled,
		'scheduledAt': scheduledAt?.toIso8601String(),
		'serviceAddress': serviceAddress,
		'createdAt': createdAt.toIso8601String(),
		'feeEstimate': feeEstimate,
		'etaMinutes': etaMinutes,
		'status': status.name,
		'paymentMethod': paymentMethod,
	};

	@override
	List<Object?> get props => [id, status, type, clientId, providerId, isScheduled];
}