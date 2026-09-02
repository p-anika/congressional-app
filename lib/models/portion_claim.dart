import 'package:cloud_firestore/cloud_firestore.dart';

class PortionClaim {
  final String id;
  final String listingId;
  final String restaurantId;
  final String userId;
  final int quantity;
  // Status flow for regular (in-person pickup) claims:
  //   'pending'   — user claimed, awaiting restaurant confirmation
  //   'confirmed' — restaurant confirmed, user is coming to pick up
  //   'declined'  — restaurant declined; portions returned to available pool
  //   'delivered' — food handed over in person
  // Status flow for delivery-based claims (created alongside a DeliveryRequest):
  //   'claimed'   — delivery claim reserved
  //   'completed' — delivery completed via completeDelivery()
  //   'cancelled' — delivery request was cancelled
  final String status;
  final DateTime claimedAt;
  final DateTime? completedAt;

  PortionClaim({
    required this.id,
    required this.listingId,
    required this.restaurantId,
    required this.userId,
    required this.quantity,
    required this.status,
    required this.claimedAt,
    this.completedAt,
  });

  factory PortionClaim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortionClaim(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      userId: data['userId'] ?? '',
      quantity: (data['quantity'] ?? 1).toInt(),
      status: data['status'] ?? 'pending',
      claimedAt: (data['claimedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'restaurantId': restaurantId,
      'userId': userId,
      'quantity': quantity,
      'status': status,
      'claimedAt': Timestamp.fromDate(claimedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}
