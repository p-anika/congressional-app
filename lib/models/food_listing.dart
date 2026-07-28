import 'package:cloud_firestore/cloud_firestore.dart';

class FoodListing {
  final String id;
  final String restaurantId;
  final String item;
  final String amount;
  final int feedsPeople; // total portions in this listing
  final List<String> allergens;
  final List<String> contains;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final double? cost; // market value per portion
  final bool isCompleted; // true once every portion has been picked up
  final DateTime? completedAt;

  final double? price; // null/0 = free; >0 = purchasable per portion
  final int claimedCount;   // portions claimed (free or sponsored), awaiting pickup
  final int completedCount; // portions actually picked up
  final int sponsoredCount; // portions paid for (volunteer or self-buyer)

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
    this.claimedCount = 0,
    this.completedCount = 0,
    this.sponsoredCount = 0,
  });

  bool get isPurchasable => (price ?? 0) > 0;

  int get totalPortions => feedsPeople;

  /// Portions a homeless person can claim right now for free — either
  /// originally free, or already paid for by a volunteer/self-buyer.
  int get availablePortions => isPurchasable
      ? (sponsoredCount - claimedCount - completedCount)
      : (totalPortions - claimedCount - completedCount);

  /// Portions still open for a volunteer (or the homeless person themself) to buy.
  int get purchasablePortionsRemaining =>
      isPurchasable ? (totalPortions - sponsoredCount) : 0;

  bool get isLastPortion => availablePortions == 1;
  bool get isFullyClaimed => completedCount >= totalPortions;

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
      claimedCount: (data['claimedCount'] ?? 0).toInt(),
      completedCount: (data['completedCount'] ?? 0).toInt(),
      sponsoredCount: (data['sponsoredCount'] ?? 0).toInt(),
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
      'claimedCount': claimedCount,
      'completedCount': completedCount,
      'sponsoredCount': sponsoredCount,
    };
  }

  bool hasAllergenConflict(List<String> userAllergies) {
    if (userAllergies.isEmpty) return false;
    final lowerAllergens = allergens.map((a) => a.toLowerCase()).toSet();
    return userAllergies.any((a) => lowerAllergens.contains(a.toLowerCase()));
  }
}