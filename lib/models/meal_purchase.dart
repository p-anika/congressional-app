import 'package:cloud_firestore/cloud_firestore.dart';

class MealPurchase {
  final String id;
  final String listingId;
  final String restaurantId;
  final String volunteerId; // buyer's uid — a volunteer OR a self-buying homeless user
  final bool isSelfPurchase;
  final String item;
  final int portions;
  final double pricePaid;
  final double marketValue;
  final double restaurantDonationAmount;
  final DateTime purchasedAt;

  MealPurchase({
    required this.id,
    required this.listingId,
    required this.restaurantId,
    required this.volunteerId,
    this.isSelfPurchase = false,
    required this.item,
    this.portions = 1,
    required this.pricePaid,
    required this.marketValue,
    required this.restaurantDonationAmount,
    required this.purchasedAt,
  });

  factory MealPurchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPurchase(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      volunteerId: data['volunteerId'] ?? '',
      isSelfPurchase: data['isSelfPurchase'] ?? false,
      item: data['item'] ?? '',
      portions: (data['portions'] ?? 1).toInt(),
      pricePaid: (data['pricePaid'] as num?)?.toDouble() ?? 0,
      marketValue: (data['marketValue'] as num?)?.toDouble() ?? 0,
      restaurantDonationAmount:
          (data['restaurantDonationAmount'] as num?)?.toDouble() ?? 0,
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'restaurantId': restaurantId,
      'volunteerId': volunteerId,
      'isSelfPurchase': isSelfPurchase,
      'item': item,
      'portions': portions,
      'pricePaid': pricePaid,
      'marketValue': marketValue,
      'restaurantDonationAmount': restaurantDonationAmount,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }
}