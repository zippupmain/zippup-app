import 'package:equatable/equatable.dart';

enum OrderCategory { transport, food, groceries, digital, hire, marketplace }

enum OrderStatus {
	pending,
	accepted,
	rejected,
	preparing,
	sorting,
	dispatched,
	assigned,
	enroute,
	arrived,
	delivered,
	cancelled,
}

class Order extends Equatable {
	final String id;
	final String buyerId;
	final String providerId;
	final String? deliveryId;
	final OrderCategory category;
	final OrderStatus status;
	final DateTime createdAt;
	final DateTime? estimatedPreparedAt;
	final String? deliveryCode;

	const Order({
		required this.id,
		required this.buyerId,
		required this.providerId,
		this.deliveryId,
		required this.category,
		required this.status,
		required this.createdAt,
		this.estimatedPreparedAt,
		this.deliveryCode,
	});

	factory Order.fromJson(String id, Map<String, dynamic> json) {
		return Order(
			id: id,
			buyerId: json['buyerId'] ?? '',
			providerId: json['providerId'] ?? '',
			deliveryId: json['deliveryId'],
			category: OrderCategory.values.firstWhere(
				(e) => e.name == (json['category'] ?? 'marketplace'),
				orElse: () => OrderCategory.marketplace,
			),
			status: OrderStatus.values.firstWhere(
				(e) => e.name == (json['status'] ?? 'pending'),
				orElse: () => OrderStatus.pending,
			),
			createdAt: (json['createdAt'] is DateTime)
				? json['createdAt'] as DateTime
				: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
			estimatedPreparedAt: json['estimatedPreparedAt'] != null
				? DateTime.tryParse(json['estimatedPreparedAt'].toString())
				: null,
			deliveryCode: json['deliveryCode'],
		);
	}

	Map<String, dynamic> toJson() => {
		'buyerId': buyerId,
		'providerId': providerId,
		'deliveryId': deliveryId,
		'category': category.name,
		'status': status.name,
		'createdAt': createdAt.toIso8601String(),
		'estimatedPreparedAt': estimatedPreparedAt?.toIso8601String(),
		'deliveryCode': deliveryCode,
	};

	@override
	List<Object?> get props => [id, status, providerId, buyerId, category];
}