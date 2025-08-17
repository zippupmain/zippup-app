import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl; // legacy single image
  final List<String> imageUrls; // new multiple images
  final double price;
  final String sellerId;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.imageUrls,
    required this.price,
    required this.sellerId,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
    imageUrls: (json['imageUrls'] is List)
        ? (json['imageUrls'] as List).map((e) => e.toString()).toList()
        : (json['imageUrl'] != null ? [json['imageUrl'].toString()] : const <String>[]),
    price: (json['price'] is num)
        ? (json['price'] as num).toDouble()
        : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
    sellerId: json['sellerId']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'price': price,
    'sellerId': sellerId,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, title, category, price];
}
