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
  final double? cost; // market value per portion
  final bool isCompleted;
  final DateTime? completedAt;
  final double? price; // modified price for homeless person. value of null or 0 means free listing; value greater than 0 = purchasable by voluteer
  final String? sponsoredByVolunteerId; // set once a volunteer buys it
  final DateTime? sponsoredAt;

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
    this.isCompleted = false,
    this.completedAt,
    this.price,
    this.sponsoredByVolunteerId,
    this.sponsoredAt,
  });

  bool get isPurchasable => (price ?? 0) > 0; // True if the restaurant listed this to be bought rather than given free.
  bool get isSponsored => sponsoredByVolunteerId != null; // True once a volunteer has bought/sponsored it for a homeless person.
  bool get isAvailableForPurchase => isAvailable && isPurchasable && !isSponsored; // True if still purchasable and nobody has bought it yet.

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
      isCompleted: data['isCompleted'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      price: (data['price'] as num?)?.toDouble(),
      sponsoredByVolunteerId: data['sponsoredByVolunteerId'],
      sponsoredAt: (data['sponsoredAt'] as Timestamp?)?.toDate(),
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
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'price': price,
      'sponsoredByVolunteerId': sponsoredByVolunteerId,
      'sponsoredAt': sponsoredAt != null ? Timestamp.fromDate(sponsoredAt!) : null,
    };
  }

  bool hasAllergenConflict(List<String> userAllergies) {
    if (userAllergies.isEmpty) return false;
    final lowerAllergens = allergens.map((a) => a.toLowerCase()).toSet();
    return userAllergies.any((a) => lowerAllergens.contains(a.toLowerCase()));
  }
}
