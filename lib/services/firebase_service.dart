import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/food_listing.dart';
import '../models/app_user.dart';
import '../models/volunteer.dart';
import '../models/meal_purchase.dart';

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

  // ── Volunteers ────────────────────────────────────────────────────────────

  static Future<void> createVolunteerDoc(Volunteer v) {
    return _db.collection('volunteers').doc(v.id).set(v.toMap());
  }

  static Future<Volunteer?> getVolunteerDocOnce(String uid) async {
    final snap = await _db.collection('volunteers').doc(uid).get();
    return snap.exists ? Volunteer.fromFirestore(snap) : null;
  }

  static Stream<Volunteer?> volunteerStream(String uid) {
    return _db
        .collection('volunteers')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? Volunteer.fromFirestore(snap) : null);
  }

  static Future<void> updateVolunteerDoc(String uid, Map<String, dynamic> data) {
    return _db.collection('volunteers').doc(uid).update(data);
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

  // ── Meal Purchases ───────────────────────────────────────────────────────

  // Listings any volunteer can currently buy: purchasable, active, unclaimed.
  // Requires a composite index (Firestore console will prompt you the first
  // time this runs — click the link it gives you to auto-create it).
  static Stream<List<FoodListing>> purchasableListingsStream() {
    return _db
        .collection('foodListings')
        .where('isAvailable', isEqualTo: true)
        .where('price', isGreaterThan: 0)
        .snapshots()
        .map((snap) => snap.docs
            .map(FoodListing.fromFirestore)
            .where((l) => !l.isSponsored)
            .toList());
  }

  // Atomically: mark the listing sponsored + write the purchase record.
  // Transaction prevents two volunteers buying the same listing at once.
  static Future<void> buyListing({
    required FoodListing listing,
    required String volunteerId,
  }) {
    final listingRef = _db.collection('foodListings').doc(listing.id);
    final purchaseRef = _db.collection('mealPurchases').doc();

    final marketValue = (listing.cost ?? listing.price ?? 0) * listing.feedsPeople;
    final pricePaid = (listing.price ?? 0) * listing.feedsPeople;
    final donation = (marketValue - pricePaid).clamp(0, double.infinity);

    return _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final freshListing = FoodListing.fromFirestore(fresh);
      if (freshListing.isSponsored || !freshListing.isAvailable) {
        throw Exception('This meal was already claimed by another volunteer.');
      }

      tx.update(listingRef, {
        'sponsoredByVolunteerId': volunteerId,
        'sponsoredAt': Timestamp.now(),
      });

      tx.set(purchaseRef, MealPurchase(
        id: purchaseRef.id,
        listingId: listing.id,
        restaurantId: listing.restaurantId,
        volunteerId: volunteerId,
        item: listing.item,
        pricePaid: pricePaid,
        marketValue: marketValue,
        restaurantDonationAmount: donation.toDouble(),
        purchasedAt: DateTime.now(),
      ).toMap());
    });
  }

  static Stream<List<MealPurchase>> purchasesByVolunteer(String volunteerId) {
    return _db
        .collection('mealPurchases')
        .where('volunteerId', isEqualTo: volunteerId)
        .snapshots()
        .map((snap) => snap.docs.map(MealPurchase.fromFirestore).toList());
  }

  static Stream<List<MealPurchase>> purchasesByRestaurant(String restaurantId) {
    return _db
        .collection('mealPurchases')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snap) => snap.docs.map(MealPurchase.fromFirestore).toList());
  }
}
