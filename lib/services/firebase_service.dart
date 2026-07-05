import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/food_listing.dart';
import '../models/app_user.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() => _auth.signOut();

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  // ── Users ─────────────────────────────────────────────────────────────────

  static Future<void> createUserDoc(AppUser user) {
    return _db.collection('users').doc(user.id).set(user.toMap());
  }

  static Future<AppUser?> getUserDocOnce(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.exists ? AppUser.fromFirestore(snap) : null;
  }

  static Stream<AppUser?> userStream(String uid) {
    print('userStream called for uid: $uid');
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          print('userStream snapshot received: exists=${snap.exists}, data=${snap.data()}');
          return snap.exists ? AppUser.fromFirestore(snap) : null;
        });
  }
  static Future<void> updateUserDoc(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update(data);
  }

  // ── Restaurants ───────────────────────────────────────────────────────────

  static Future<DocumentReference> createRestaurant(Restaurant r) {
    return _db.collection('restaurants').add(r.toMap());
  }

  static Future<void> updateRestaurant(String id, Map<String, dynamic> data) {
    return _db.collection('restaurants').doc(id).update(data);
  }

  static Stream<Restaurant?> restaurantByOwner(String ownerId) {
    return _db
        .collection('restaurants')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isNotEmpty ? Restaurant.fromFirestore(snap.docs.first) : null);
  }

  static Stream<List<Restaurant>> verifiedRestaurantsStream() {
    return _db
        .collection('restaurants')
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Restaurant.fromFirestore).toList());
  }

  static Stream<Restaurant?> restaurantStream(String id) {
    return _db
        .collection('restaurants')
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? Restaurant.fromFirestore(snap) : null);
  }

  // ── Food Listings ─────────────────────────────────────────────────────────

  static Future<void> addFoodListing(FoodListing listing) {
    return _db.collection('foodListings').add(listing.toMap());
  }

  static Future<void> updateFoodListing(String id, Map<String, dynamic> data) {
    return _db.collection('foodListings').doc(id).update(data);
  }

  static Future<void> deleteFoodListing(String id) {
    return _db.collection('foodListings').doc(id).delete();
  }

  // All listings for a restaurant (restaurant management view — includes unavailable)
  static Stream<List<FoodListing>> allListingsByRestaurant(String restaurantId) {
    return _db
        .collection('foodListings')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snap) => snap.docs.map(FoodListing.fromFirestore).toList());
  }

  // Active-only listings for a specific restaurant (user-facing)
  static Stream<List<FoodListing>> listingsByRestaurant(String restaurantId) {
    return _db
        .collection('foodListings')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(FoodListing.fromFirestore).toList());
  }

  static Stream<List<FoodListing>> allActiveListings() {
    return _db
        .collection('foodListings')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(FoodListing.fromFirestore).toList());
  }

  static Stream<List<FoodListing>> completedListingsByRestaurant(
      String restaurantId) {
    return _db
        .collection('foodListings')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final listings =
          snap.docs.map(FoodListing.fromFirestore).toList();
      listings.sort((a, b) =>
          (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
      return listings;
    });
  }
}
