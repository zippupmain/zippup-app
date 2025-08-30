import 'package:equatable/equatable.dart';

enum PersonalType { beauty, wellness, fitness, tutoring, cleaning, childcare }

enum PersonalStatus { requested, accepted, arriving, arrived, inProgress, completed, cancelled }

class PersonalBooking extends Equatable {
	final String id;
	final String clientId;
	final String? providerId;
	final PersonalType type;
	final String serviceCategory;
	final String description;
	final String serviceAddress;
	final DateTime createdAt;
	final bool isScheduled;
	final DateTime? scheduledAt;
	final double feeEstimate;
	final int etaMinutes;
	final PersonalStatus status;
	final String? paymentMethod;
	final int? durationMinutes;

	const PersonalBooking({
		required this.id,
		required this.clientId,
		this.providerId,
		required this.type,
		required this.serviceCategory,
		required this.description,
		required this.serviceAddress,
		required this.createdAt,
		required this.isScheduled,
		this.scheduledAt,
		required this.feeEstimate,
		required this.etaMinutes,
		required this.status,
		this.paymentMethod,
		this.durationMinutes,
	});

	factory PersonalBooking.fromJson(String id, Map<String, dynamic> json) => PersonalBooking(
		id: id,
		clientId: json['clientId'] ?? '',
		providerId: json['providerId'],
		type: PersonalType.values.firstWhere((e) => e.name == (json['type'] ?? 'beauty'), orElse: () => PersonalType.beauty),
		serviceCategory: json['serviceCategory'] ?? '',
		description: json['description'] ?? '',
		serviceAddress: json['serviceAddress'] ?? '',
		createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
		isScheduled: json['isScheduled'] == true,
		scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null,
		feeEstimate: (json['feeEstimate'] is num) ? (json['feeEstimate'] as num).toDouble() : 0,
		etaMinutes: (json['etaMinutes'] is num) ? (json['etaMinutes'] as num).toInt() : 0,
		status: PersonalStatus.values.firstWhere((e) => e.name == (json['status'] ?? 'requested'), orElse: () => PersonalStatus.requested),
		paymentMethod: json['paymentMethod'],
		durationMinutes: (json['durationMinutes'] is num) ? (json['durationMinutes'] as num).toInt() : null,
	);

	Map<String, dynamic> toJson() => {
		'clientId': clientId,
		'providerId': providerId,
		'type': type.name,
		'serviceCategory': serviceCategory,
		'description': description,
		'serviceAddress': serviceAddress,
		'createdAt': createdAt.toIso8601String(),
		'isScheduled': isScheduled,
		'scheduledAt': scheduledAt?.toIso8601String(),
		'feeEstimate': feeEstimate,
		'etaMinutes': etaMinutes,
		'status': status.name,
		'paymentMethod': paymentMethod,
		'durationMinutes': durationMinutes,
	};

	@override
	List<Object?> get props => [id, status, type, clientId, providerId, isScheduled];
}