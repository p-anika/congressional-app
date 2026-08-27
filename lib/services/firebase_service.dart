import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/food_listing.dart';
import '../models/app_user.dart';
import '../models/volunteer.dart';
import '../models/meal_purchase.dart';
import '../models/portion_claim.dart';
import '../models/delivery_request.dart';

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
    bool requestDelivery = false,
    double? dropoffLat,
    double? dropoffLng,
    String? buyerPhone,
  }) async {
    // Delivery only makes sense for a self-buyer requesting it for themself —
    // a volunteer sponsoring for someone else already leaves the portion
    // open for that person to claim (or request delivery) separately.
    final wantsDelivery = isSelfPurchase && requestDelivery;

    Restaurant? restaurant;
    if (wantsDelivery) {
      if (dropoffLat == null || dropoffLng == null) {
        throw Exception('A drop-off location is required to request delivery.');
      }
      restaurant = await getRestaurantOnce(listing.restaurantId);
      if (restaurant == null) {
        throw Exception('Could not find the restaurant for this listing.');
      }
    }

    final listingRef = _db.collection('foodListings').doc(listing.id);
    final purchaseRef = _db.collection('mealPurchases').doc();
    final claimRef = _db.collection('portionClaims').doc();
    final deliveryRef = _db.collection('deliveryRequests').doc();

    final perPortionCost = listing.cost ?? listing.price ?? 0;
    final marketValue = perPortionCost * quantity;
    final pricePaid = (listing.price ?? 0) * quantity;
    final donation = (marketValue - pricePaid).clamp(0, double.infinity);

    await _db.runTransaction((tx) async {
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

      // Self-buyer opted for delivery instead of picking it up themselves —
      // create a delivery request tied to the same claim, so completeDelivery
      // later marks the claim/listing completed exactly like a free delivery.
      if (wantsDelivery) {
        tx.set(
          deliveryRef,
          DeliveryRequest(
            id: deliveryRef.id,
            listingId: listing.id,
            claimId: claimRef.id,
            restaurantId: listing.restaurantId,
            restaurantName: restaurant!.name,
            item: listing.item,
            quantity: quantity,
            userId: buyerId,
            userPhone: buyerPhone ?? '',
            pickupLat: restaurant.lat,
            pickupLng: restaurant.lng,
            pickupAddress: restaurant.address,
            dropoffLat: dropoffLat!,
            dropoffLng: dropoffLng!,
            status: 'pending',
            requestedAt: DateTime.now(),
          ).toMap(),
        );
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

  // ── Delivery Requests ────────────────────────────────────────────────────
  // A homeless user who thinks a listing is too far to walk to can request
  // that a volunteer pick it up and bring it to their saved location. This
  // reserves the portion(s) the same way a free claim does, but tags the
  // claim with pickup/drop-off coordinates a volunteer can act on.

  static Future<void> requestDelivery({
    required FoodListing listing,
    required String userId,
    required int quantity,
    required double userLat,
    required double userLng,
    String? userPhone,
  }) async {
    final restaurant = await getRestaurantOnce(listing.restaurantId);
    if (restaurant == null) {
      throw Exception('Could not find the restaurant for this listing.');
    }

    final listingRef = _db.collection('foodListings').doc(listing.id);
    final claimRef = _db.collection('portionClaims').doc();
    final deliveryRef = _db.collection('deliveryRequests').doc();

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(listingRef);
      final freshListing = FoodListing.fromFirestore(fresh);
      if (!freshListing.isAvailable ||
          freshListing.availablePortions < quantity) {
        throw Exception(
            'Not enough portions left — someone else may have just claimed one.');
      }

      tx.update(listingRef, {
        'claimedCount': freshListing.claimedCount + quantity,
      });

      tx.set(
        claimRef,
        PortionClaim(
          id: claimRef.id,
          listingId: listing.id,
          restaurantId: listing.restaurantId,
          userId: userId,
          quantity: quantity,
          status: 'claimed',
          paidBySelf: false,
          claimedAt: DateTime.now(),
        ).toMap(),
      );

      tx.set(
        deliveryRef,
        DeliveryRequest(
          id: deliveryRef.id,
          listingId: listing.id,
          claimId: claimRef.id,
          restaurantId: listing.restaurantId,
          restaurantName: restaurant.name,
          item: listing.item,
          quantity: quantity,
          userId: userId,
          userPhone: userPhone ?? '',
          pickupLat: restaurant.lat,
          pickupLng: restaurant.lng,
          pickupAddress: restaurant.address,
          dropoffLat: userLat,
          dropoffLng: userLng,
          status: 'pending',
          requestedAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  static Stream<List<DeliveryRequest>> pendingDeliveryRequestsStream() {
    return _db
        .collection('deliveryRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(DeliveryRequest.fromFirestore).toList());
  }

  static Stream<List<DeliveryRequest>> volunteerDeliveriesStream(
      String volunteerId) {
    return _db
        .collection('deliveryRequests')
        .where('volunteerId', isEqualTo: volunteerId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map(DeliveryRequest.fromFirestore).toList());
  }

  static Stream<List<DeliveryRequest>> userDeliveryRequestsStream(
      String userId) {
    return _db
        .collection('deliveryRequests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(DeliveryRequest.fromFirestore).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  static Future<void> acceptDeliveryRequest(
      String requestId, String volunteerId) {
    final ref = _db.collection('deliveryRequests').doc(requestId);
    return _db.runTransaction((tx) async {
      final fresh = await tx.get(ref);
      if (!fresh.exists) {
        throw Exception('This delivery request no longer exists.');
      }
      final data = fresh.data() as Map<String, dynamic>;
      if (data['status'] != 'pending') {
        throw Exception('Another volunteer already accepted this delivery.');
      }
      tx.update(ref, {
        'volunteerId': volunteerId,
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });
    });
  }

  static Future<void> cancelDeliveryRequest(String requestId) async {
    final ref = _db.collection('deliveryRequests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final request = DeliveryRequest.fromFirestore(snap);
    final listingRef = _db.collection('foodListings').doc(request.listingId);
    final claimRef = _db.collection('portionClaims').doc(request.claimId);

    await _db.runTransaction((tx) async {
      final freshListingSnap = await tx.get(listingRef);
      if (freshListingSnap.exists) {
        final freshListing = FoodListing.fromFirestore(freshListingSnap);
        final newClaimed = freshListing.claimedCount - request.quantity;
        tx.update(listingRef, {'claimedCount': newClaimed < 0 ? 0 : newClaimed});
      }
      tx.update(claimRef, {'status': 'cancelled'});
      tx.update(ref, {'status': 'cancelled'});
    });
  }

  static Future<void> completeDelivery(String requestId) {
    final ref = _db.collection('deliveryRequests').doc(requestId);
    return _db.runTransaction((tx) async {
      final fresh = await tx.get(ref);
      if (!fresh.exists) {
        throw Exception('This delivery request no longer exists.');
      }
      final request = DeliveryRequest.fromFirestore(fresh);
      if (request.status != 'accepted') {
        throw Exception('This delivery is not in a deliverable state.');
      }

      final listingRef = _db.collection('foodListings').doc(request.listingId);
      final claimRef = _db.collection('portionClaims').doc(request.claimId);

      final listingSnap = await tx.get(listingRef);
      final listing = FoodListing.fromFirestore(listingSnap);

      final newCompleted = listing.completedCount + request.quantity;
      final newClaimed = listing.claimedCount - request.quantity;

      tx.update(listingRef, {
        'completedCount': newCompleted,
        'claimedCount': newClaimed < 0 ? 0 : newClaimed,
        if (newCompleted >= listing.totalPortions) ...{
          'isCompleted': true,
          'completedAt': Timestamp.now(),
          'isAvailable': false,
        },
      });

      tx.update(claimRef, {
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      tx.update(ref, {
        'status': 'delivered',
        'deliveredAt': Timestamp.now(),
      });
    });
  }

    static Stream<List<DeliveryRequest>> volunteerDeliveryHistoryStream(
      String volunteerId) {
    return _db
        .collection('deliveryRequests')
        .where('volunteerId', isEqualTo: volunteerId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(DeliveryRequest.fromFirestore).toList();
      list.sort((a, b) =>
          (b.deliveredAt ?? DateTime(0)).compareTo(a.deliveredAt ?? DateTime(0)));
      return list;
    });
  }
}
