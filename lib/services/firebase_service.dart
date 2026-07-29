import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/food_listing.dart';
import '../models/app_user.dart';
import '../models/volunteer.dart';
import '../models/meal_purchase.dart';
import '../models/portion_claim.dart';

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

  // One-time fetch, used for building history views (My Claims) where the
  // listing may no longer be in the live "active listings" stream.
  static Future<FoodListing?> getListingOnce(String id) async {
    final snap = await _db.collection('foodListings').doc(id).get();
    return snap.exists ? FoodListing.fromFirestore(snap) : null;
  }

  static Future<Restaurant?> getRestaurantOnce(String id) async {
    final snap = await _db.collection('restaurants').doc(id).get();
    return snap.exists ? Restaurant.fromFirestore(snap) : null;
  }

  // Restaurant records that a walk-in (non-app) customer took a portion for
  // free, in real time — keeps in-app counts honest as pickups happen,
  // rather than only reconciling at listing end.
  static Future<void> recordWalkInPickup(String listingId) {
    final listingRef = _db.collection('foodListings').doc(listingId);
    return _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final listing = FoodListing.fromFirestore(fresh);
      if (listing.availablePortions <= 0) {
        throw Exception('No available portions left to record.');
      }
      final newCompleted = listing.completedCount + 1;
      tx.update(listingRef, {
        'completedCount': newCompleted,
        if (newCompleted >= listing.totalPortions) ...{
          'isCompleted': true,
          'completedAt': Timestamp.now(),
          'isAvailable': false,
        },
      });
    });
  }

  // Ends a listing early, with an explicit reason that determines whether
  // remaining unclaimed portions count toward the donation total:
  //  - 'donatedInPerson': off-app pickup, credited as a donation
  //  - 'spoiled': discarded, no credit
  //  - 'soldElsewhere': sold to a paying walk-in, not charity, no credit
  static Future<void> endListing(String listingId, String reason) {
    final listingRef = _db.collection('foodListings').doc(listingId);
    return _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final listing = FoodListing.fromFirestore(fresh);
      final remaining =
          listing.totalPortions - listing.claimedCount - listing.completedCount;

      final updates = <String, dynamic>{
        'isAvailable': false,
        'isCompleted': true,
        'completedAt': Timestamp.now(),
      };
      if (reason == 'donatedInPerson' && remaining > 0) {
        updates['completedCount'] = listing.completedCount + remaining;
      }
      tx.update(listingRef, updates);
    });
  }

  // ── Portion Claims (free, or already-sponsored, portions) ───────────────

  static Future<void> claimPortions({
    required FoodListing listing,
    required String userId,
    required int quantity,
  }) {
    final listingRef = _db.collection('foodListings').doc(listing.id);
    final claimRef = _db.collection('portionClaims').doc();

    return _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final freshListing = FoodListing.fromFirestore(fresh);
      if (!freshListing.isAvailable || freshListing.availablePortions < quantity) {
        throw Exception(
            'Not enough portions left — someone else may have just claimed one.');
      }

      tx.update(listingRef, {
        'claimedCount': freshListing.claimedCount + quantity,
      });

      tx.set(claimRef, PortionClaim(
        id: claimRef.id,
        listingId: listing.id,
        restaurantId: listing.restaurantId,
        userId: userId,
        quantity: quantity,
        status: 'claimed',
        paidBySelf: false,
        claimedAt: DateTime.now(),
      ).toMap());
    });
  }

  static Stream<List<PortionClaim>> claimsByListing(String listingId) {
    return _db
        .collection('portionClaims')
        .where('listingId', isEqualTo: listingId)
        .where('status', isEqualTo: 'claimed')
        .snapshots()
        .map((snap) {
      final claims = snap.docs.map(PortionClaim.fromFirestore).toList();
      claims.sort((a, b) => a.claimedAt.compareTo(b.claimedAt));
      return claims;
    });
  }

  static Stream<List<PortionClaim>> claimsByUser(String userId) {
    return _db
        .collection('portionClaims')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map(PortionClaim.fromFirestore).toList());
  }

  // Restaurant marks the oldest outstanding claim on a listing as picked up.
  // No server-side orderBy here on purpose (see the composite-index lesson
  // from purchasableListingsStream earlier) — sort client-side instead.
  static Future<void> completeOldestClaim(String listingId) {
    final listingRef = _db.collection('foodListings').doc(listingId);

    return _db.runTransaction((tx) async {
      final claimsSnap = await _db
          .collection('portionClaims')
          .where('listingId', isEqualTo: listingId)
          .where('status', isEqualTo: 'claimed')
          .get();

      if (claimsSnap.docs.isEmpty) {
        throw Exception('No pending claims to complete for this listing.');
      }

      final sortedDocs = claimsSnap.docs.toList()
        ..sort((a, b) => (a.data()['claimedAt'] as Timestamp)
            .compareTo(b.data()['claimedAt'] as Timestamp));
      final claimDoc = sortedDocs.first;
      final claim = PortionClaim.fromFirestore(claimDoc);

      final fresh = await tx.get(listingRef);
      final freshListing = FoodListing.fromFirestore(fresh);

      final newCompleted = freshListing.completedCount + claim.quantity;
      final newClaimed = freshListing.claimedCount - claim.quantity;

      tx.update(listingRef, {
        'completedCount': newCompleted,
        'claimedCount': newClaimed < 0 ? 0 : newClaimed,
        if (newCompleted >= freshListing.totalPortions) ...{
          'isCompleted': true,
          'completedAt': Timestamp.now(),
          'isAvailable': false,
        },
      });

      tx.update(claimDoc.reference, {
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });
    });
  }

  // ── Portion Purchases (volunteer sponsoring for someone else, OR a
  //    homeless person buying a discounted portion for themself) ──────────

  static Stream<List<FoodListing>> purchasableListingsStream() {
    return _db
        .collection('foodListings')
        .snapshots()
        .map((snap) => snap.docs
            .map(FoodListing.fromFirestore)
            .where((l) => l.isAvailable && l.purchasablePortionsRemaining > 0)
            .toList());
  }

  static Future<void> purchasePortions({
    required FoodListing listing,
    required String buyerId,
    required int quantity,
    required bool isSelfPurchase,
  }) {
    final listingRef = _db.collection('foodListings').doc(listing.id);
    final purchaseRef = _db.collection('mealPurchases').doc();
    final claimRef = _db.collection('portionClaims').doc();

    final perPortionCost = listing.cost ?? listing.price ?? 0;
    final marketValue = perPortionCost * quantity;
    final pricePaid = (listing.price ?? 0) * quantity;
    final donation = (marketValue - pricePaid).clamp(0, double.infinity);

    return _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final freshListing = FoodListing.fromFirestore(fresh);
      if (!freshListing.isAvailable ||
          freshListing.purchasablePortionsRemaining < quantity) {
        throw Exception('Not enough portions left to buy — try a smaller amount.');
      }

      final updates = <String, dynamic>{
        'sponsoredCount': freshListing.sponsoredCount + quantity,
      };
      if (isSelfPurchase) {
        updates['claimedCount'] = freshListing.claimedCount + quantity;
      }
      tx.update(listingRef, updates);

      tx.set(purchaseRef, MealPurchase(
        id: purchaseRef.id,
        listingId: listing.id,
        restaurantId: listing.restaurantId,
        volunteerId: buyerId,
        isSelfPurchase: isSelfPurchase,
        item: listing.item,
        portions: quantity,
        pricePaid: pricePaid,
        marketValue: marketValue,
        restaurantDonationAmount: donation.toDouble(),
        purchasedAt: DateTime.now(),
      ).toMap());

      // Only self-buyers are immediately "claimed" — a volunteer sponsoring
      // for someone else leaves the portion open for a homeless person to
      // claim for free via claimPortions().
      if (isSelfPurchase) {
        tx.set(claimRef, PortionClaim(
          id: claimRef.id,
          listingId: listing.id,
          restaurantId: listing.restaurantId,
          userId: buyerId,
          quantity: quantity,
          status: 'claimed',
          paidBySelf: true,
          claimedAt: DateTime.now(),
        ).toMap());
      }
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
