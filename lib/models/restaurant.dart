import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String contactInfo;
  final String hoursOfOperation;
  final bool isVerified;
  final String ownerId;
  final double? lastYearRevenue;
  final double? projectedGrowth;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.contactInfo,
    required this.hoursOfOperation,
    required this.isVerified,
    required this.ownerId,
    this.lastYearRevenue,
    this.projectedGrowth,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      contactInfo: data['contactInfo'] ?? '',
      hoursOfOperation: data['hoursOfOperation'] ?? '',
      isVerified: data['isVerified'] ?? false,
      ownerId: data['ownerId'] ?? '',
      lastYearRevenue: (data['lastYearRevenue'] as num?)?.toDouble(),
      projectedGrowth: (data['projectedGrowth'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'contactInfo': contactInfo,
      'hoursOfOperation': hoursOfOperation,
      'isVerified': isVerified,
      'ownerId': ownerId,
      'lastYearRevenue': lastYearRevenue,
      'projectedGrowth': projectedGrowth,
    };
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? contactInfo,
    String? hoursOfOperation,
    bool? isVerified,
    String? ownerId,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      contactInfo: contactInfo ?? this.contactInfo,
      hoursOfOperation: hoursOfOperation ?? this.hoursOfOperation,
      isVerified: isVerified ?? this.isVerified,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}
