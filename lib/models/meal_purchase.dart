import 'package:cloud_firestore/cloud_firestore.dart';

class MealPurchase {
  final String id;
  final String listingId;
  final String restaurantId;
  final String volunteerId;
  final String item; // snapshot of listing.item at purchase time, for display
  final double pricePaid;
  final double marketValue; // snapshot of listing.cost * feedsPeople
  final double restaurantDonationAmount; // marketValue - pricePaid
  final DateTime purchasedAt;

  MealPurchase({
    required this.id,
    required this.listingId,
    required this.restaurantId,
    required this.volunteerId,
    required this.item,
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
      item: data['item'] ?? '',
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
      'item': item,
      'pricePaid': pricePaid,
      'marketValue': marketValue,
      'restaurantDonationAmount': restaurantDonationAmount,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }
}