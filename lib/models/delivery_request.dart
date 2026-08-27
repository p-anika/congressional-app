import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryRequest {
  final String id;
  final String listingId;
  final String claimId; // linked PortionClaim reserving the portion(s)
  final String restaurantId;
  final String restaurantName;
  final String item;
  final int quantity;
  final String userId;
  final String userPhone;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String status; // 'pending' | 'accepted' | 'delivered' | 'cancelled'
  final String? volunteerId;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;

  DeliveryRequest({
    required this.id,
    required this.listingId,
    required this.claimId,
    required this.restaurantId,
    required this.restaurantName,
    required this.item,
    required this.quantity,
    required this.userId,
    this.userPhone = '',
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.status = 'pending',
    this.volunteerId,
    required this.requestedAt,
    this.acceptedAt,
    this.deliveredAt,
  });

  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeliveryRequest(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      claimId: data['claimId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      item: data['item'] ?? '',
      quantity: (data['quantity'] ?? 1).toInt(),
      userId: data['userId'] ?? '',
      userPhone: data['userPhone'] ?? '',
      pickupLat: (data['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (data['pickupLng'] ?? 0.0).toDouble(),
      pickupAddress: data['pickupAddress'] ?? '',
      dropoffLat: (data['dropoffLat'] ?? 0.0).toDouble(),
      dropoffLng: (data['dropoffLng'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      volunteerId: data['volunteerId'],
      requestedAt:
          (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'claimId': claimId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'item': item,
      'quantity': quantity,
      'userId': userId,
      'userPhone': userPhone,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'status': status,
      'volunteerId': volunteerId,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'acceptedAt':
          acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    };
  }
}