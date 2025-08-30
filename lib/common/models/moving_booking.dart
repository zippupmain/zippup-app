import 'package:equatable/equatable.dart';

enum MovingType { local, interstate, office, storage }

enum MovingStatus { requested, accepted, arriving, arrived, loading, inTransit, unloading, completed, cancelled }

class MovingBooking extends Equatable {
	final String id;
	final String clientId;
	final String? providerId;
	final MovingType type;
	final String description;
	final String pickupAddress;
	final String destinationAddress;
	final DateTime createdAt;
	final bool isScheduled;
	final DateTime? scheduledAt;
	final double feeEstimate;
	final int etaMinutes;
	final MovingStatus status;
	final String? paymentMethod;
	final List<String>? itemsList;

	const MovingBooking({
		required this.id,
		required this.clientId,
		this.providerId,
		required this.type,
		required this.description,
		required this.pickupAddress,
		required this.destinationAddress,
		required this.createdAt,
		required this.isScheduled,
		this.scheduledAt,
		required this.feeEstimate,
		required this.etaMinutes,
		required this.status,
		this.paymentMethod,
		this.itemsList,
	});

	factory MovingBooking.fromJson(String id, Map<String, dynamic> json) => MovingBooking(
		id: id,
		clientId: json['clientId'] ?? '',
		providerId: json['providerId'],
		type: MovingType.values.firstWhere((e) => e.name == (json['type'] ?? 'local'), orElse: () => MovingType.local),
		description: json['description'] ?? '',
		pickupAddress: json['pickupAddress'] ?? '',
		destinationAddress: json['destinationAddress'] ?? '',
		createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
		isScheduled: json['isScheduled'] == true,
		scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null,
		feeEstimate: (json['feeEstimate'] is num) ? (json['feeEstimate'] as num).toDouble() : 0,
		etaMinutes: (json['etaMinutes'] is num) ? (json['etaMinutes'] as num).toInt() : 0,
		status: MovingStatus.values.firstWhere((e) => e.name == (json['status'] ?? 'requested'), orElse: () => MovingStatus.requested),
		paymentMethod: json['paymentMethod'],
		itemsList: (json['itemsList'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
	);

	Map<String, dynamic> toJson() => {
		'clientId': clientId,
		'providerId': providerId,
		'type': type.name,
		'description': description,
		'pickupAddress': pickupAddress,
		'destinationAddress': destinationAddress,
		'createdAt': createdAt.toIso8601String(),
		'isScheduled': isScheduled,
		'scheduledAt': scheduledAt?.toIso8601String(),
		'feeEstimate': feeEstimate,
		'etaMinutes': etaMinutes,
		'status': status.name,
		'paymentMethod': paymentMethod,
		'itemsList': itemsList,
	};

	@override
	List<Object?> get props => [id, status, type, clientId, providerId, isScheduled];
}