import 'package:cloud_firestore/cloud_firestore.dart';

class FoodListing {
  final String id;
  final String restaurantId;
  final String item;
  final String amount;
  final int feedsPeople;
  final List<String> allergens;
  final List<String> contains;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final double? cost;

  FoodListing({
    required this.id,
    required this.restaurantId,
    required this.item,
    required this.amount,
    required this.feedsPeople,
    required this.allergens,
    required this.contains,
    required this.isAvailable,
    required this.createdAt,
    this.expiresAt,
    this.cost,
  });

  factory FoodListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodListing(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      item: data['item'] ?? '',
      amount: data['amount'] ?? '',
      feedsPeople: (data['feedsPeople'] ?? 0).toInt(),
      allergens: List<String>.from(data['allergens'] ?? []),
      contains: List<String>.from(data['contains'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      cost: (data['cost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'item': item,
      'amount': amount,
      'feedsPeople': feedsPeople,
      'allergens': allergens,
      'contains': contains,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'cost': cost,
    };
  }

  bool hasAllergenConflict(List<String> userAllergies) {
    if (userAllergies.isEmpty) return false;
    final lowerAllergens = allergens.map((a) => a.toLowerCase()).toSet();
    return userAllergies.any((a) => lowerAllergens.contains(a.toLowerCase()));
  }
}
