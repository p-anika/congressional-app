import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String role; // "restaurant" | "user"
  final List<String> allergies;
  final GeoPoint? location;
  final String phone;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.allergies,
    this.location,
    required this.phone,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      allergies: List<String>.from(data['allergies'] ?? []),
      location: data['location'] as GeoPoint?,
      phone: data['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'allergies': allergies,
      'location': location,
      'phone': phone,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? role,
    List<String>? allergies,
    GeoPoint? location,
    String? phone,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      allergies: allergies ?? this.allergies,
      location: location ?? this.location,
      phone: phone ?? this.phone,
    );
  }
}
