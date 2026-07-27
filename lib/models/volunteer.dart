import 'package:cloud_firestore/cloud_firestore.dart';

class Volunteer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String organization; // may be empty
  final bool isApproved;     // admin-reviewed, like Restaurant.isVerified

  Volunteer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.organization,
    required this.isApproved,
  });

  factory Volunteer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Volunteer(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      organization: data['organization'] ?? '',
      isApproved: data['isApproved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'organization': organization,
      'isApproved': isApproved,
      'ownerId': id, // set to uid when creating, see below
    };
  }
}