import 'package:cloud_firestore/cloud_firestore.dart';


class RescueStatus {
  static const open = 'open';
  static const claimed = 'claimed';
  static const pickupPendingRestaurant = 'pickup_pending_restaurant';
  static const pickedUp = 'picked_up';
  static const deliveredPendingRecipient = 'delivered_pending_recipient';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const disputed = 'disputed';

  static const active = [
    claimed,
    pickupPendingRestaurant,
    pickedUp,
    deliveredPendingRecipient,
  ];
}

// a recipient's request for a helper to bring food from a restaurant listing
// exact drop-off address in [RescueDropoff] so only the recipient and the helper can read it
class RescueRequest {
  final String id;
  final String code;
  final String listingId;
  final String claimId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final double restaurantLat;
  final double restaurantLng;
  final String item;
  final int quantity;
  final String recipientId;
  final String? helperId;
  final String status;
  // Rounded to ~1 km so helpers browsing open requests can judge distance without seeing where the recipient actually is
  final double? approxLat;
  final double? approxLng;
  final DateTime? createdAt;
  final DateTime? claimedAt;
  final DateTime? pickupReportedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? disputedAt;
  final DateTime? cancelledAt;
  final DateTime? handoffRejectedAt;

  RescueRequest({
    required this.id,
    required this.code,
    required this.listingId,
    required this.claimId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.item,
    required this.quantity,
    required this.recipientId,
    this.helperId,
    required this.status,
    this.approxLat,
    this.approxLng,
    this.createdAt,
    this.claimedAt,
    this.pickupReportedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.completedAt,
    this.disputedAt,
    this.cancelledAt,
    this.handoffRejectedAt,
  });

  bool get isActive => RescueStatus.active.contains(status);

  static DateTime? _date(dynamic v) => (v as Timestamp?)?.toDate();

  factory RescueRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RescueRequest(
      id: doc.id,
      code: data['code'] ?? '',
      listingId: data['listingId'] ?? '',
      claimId: data['claimId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      restaurantAddress: data['restaurantAddress'] ?? '',
      restaurantLat: (data['restaurantLat'] ?? 0.0).toDouble(),
      restaurantLng: (data['restaurantLng'] ?? 0.0).toDouble(),
      item: data['item'] ?? '',
      quantity: (data['quantity'] ?? 1).toInt(),
      recipientId: data['recipientId'] ?? '',
      helperId: data['helperId'],
      status: data['status'] ?? RescueStatus.open,
      approxLat: (data['approxLat'] as num?)?.toDouble(),
      approxLng: (data['approxLng'] as num?)?.toDouble(),
      createdAt: _date(data['createdAt']),
      claimedAt: _date(data['claimedAt']),
      pickupReportedAt: _date(data['pickupReportedAt']),
      pickedUpAt: _date(data['pickedUpAt']),
      deliveredAt: _date(data['deliveredAt']),
      completedAt: _date(data['completedAt']),
      disputedAt: _date(data['disputedAt']),
      cancelledAt: _date(data['cancelledAt']),
      handoffRejectedAt: _date(data['handoffRejectedAt']),
    );
  }
}


class RescueDropoff {
  final String address;
  final double? lat;
  final double? lng;
  final String notes; // apartment #, buzzer, number of people, etc.
  // True when lat/lng are only the city/zip center (exact address not found).
  final bool locationApproximate;

  RescueDropoff({
    required this.address,
    this.lat,
    this.lng,
    this.notes = '',
    this.locationApproximate = false,
  });

  bool get hasCoordinates => lat != null && lng != null;

  factory RescueDropoff.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RescueDropoff(
      address: data['address'] ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      notes: data['notes'] ?? '',
      locationApproximate: data['locationApproximate'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': lat,
      'lng': lng,
      'notes': notes,
      'locationApproximate': locationApproximate,
    };
  }
}
