import 'package:cloud_firestore/cloud_firestore.dart';

class PortionClaim {
  final String id;
  final String listingId;
  final String restaurantId;
  final String userId;
  final int quantity;
  final String status; // 'claimed' | 'completed'
  final bool paidBySelf; // true if this user bought it themselves (not free/sponsored)
  final DateTime claimedAt;
  final DateTime? completedAt;

  PortionClaim({
    required this.id,
    required this.listingId,
    required this.restaurantId,
    required this.userId,
    required this.quantity,
    required this.status,
    this.paidBySelf = false,
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
      status: data['status'] ?? 'claimed',
      paidBySelf: data['paidBySelf'] ?? false,
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
      'paidBySelf': paidBySelf,
      'claimedAt': Timestamp.fromDate(claimedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}