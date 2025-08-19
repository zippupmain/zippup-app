import 'package:equatable/equatable.dart';

enum RideType { taxi, bike, courier, bus, tricycle }

enum RideStatus { requested, accepted, arriving, arrived, enroute, completed, cancelled }

class Ride extends Equatable {
	final String id;
	final String riderId;
	final String? driverId;
	final RideType type;
	final bool isScheduled;
	final DateTime? scheduledAt;
	final String pickupAddress;
	final List<String> destinationAddresses;
	final DateTime createdAt;
	final double fareEstimate;
	final int etaMinutes;
	final RideStatus status;

	const Ride({
		required this.id,
		required this.riderId,
		this.driverId,
		required this.type,
		required this.isScheduled,
		this.scheduledAt,
		required this.pickupAddress,
		required this.destinationAddresses,
		required this.createdAt,
		required this.fareEstimate,
		required this.etaMinutes,
		required this.status,
	});

	factory Ride.fromJson(String id, Map<String, dynamic> json) => Ride(
		id: id,
		riderId: json['riderId'] ?? '',
		driverId: json['driverId'],
		type: RideType.values.firstWhere((e) => e.name == (json['type'] ?? 'taxi'), orElse: () => RideType.taxi),
		isScheduled: json['isScheduled'] == true,
		scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null,
		pickupAddress: json['pickupAddress'] ?? '',
		destinationAddresses: (json['destinationAddresses'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
		createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
		fareEstimate: (json['fareEstimate'] is num) ? (json['fareEstimate'] as num).toDouble() : 0,
		etaMinutes: (json['etaMinutes'] is num) ? (json['etaMinutes'] as num).toInt() : 0,
		status: RideStatus.values.firstWhere((e) => e.name == (json['status'] ?? 'requested'), orElse: () => RideStatus.requested),
	);

	Map<String, dynamic> toJson() => {
		'riderId': riderId,
		'driverId': driverId,
		'type': type.name,
		'isScheduled': isScheduled,
		'scheduledAt': scheduledAt?.toIso8601String(),
		'pickupAddress': pickupAddress,
		'destinationAddresses': destinationAddresses,
		'createdAt': createdAt.toIso8601String(),
		'fareEstimate': fareEstimate,
		'etaMinutes': etaMinutes,
		'status': status.name,
	};

	@override
	List<Object?> get props => [id, status, type, riderId, driverId, isScheduled];
}