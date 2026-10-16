import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/food_listing.dart';
import '../models/portion_claim.dart';
import '../models/rescue_request.dart';
import 'firebase_service.dart';
import 'location_service.dart';

/// Request + delivery flow between a recipient, a helper (volunteer) and the
/// restaurant. Every status change runs in a transaction that re-reads the
/// doc and checks the current status + who is acting, so steps can't be
/// skipped or double-claimed. The same checks are enforced server-side in
/// firestore.rescue_requests.rules.
class RescueService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('rescueRequests');

  static DocumentReference<Map<String, dynamic>> _dropoffRef(String id) =>
      _col.doc(id).collection('private').doc('dropoff');

  // ── Create (recipient) ────────────────────────────────────────────────────

  // Reserves the portion(s) the same way the existing delivery flow does
  // (claimedCount + a 'claimed' PortionClaim), then writes the public request
  // doc and the private drop-off doc together.
  static Future<String> createRequest({
    required FoodListing listing,
    required String recipientId,
    required int quantity,
    required RescueDropoff dropoff,
  }) async {
    final restaurant = await FirebaseService.getRestaurantOnce(listing.restaurantId);
    if (restaurant == null) {
      throw Exception('Could not find the restaurant for this listing.');
    }

    final listingRef = _db.collection('foodListings').doc(listing.id);
    final claimRef = _db.collection('portionClaims').doc();
    final ref = _col.doc();
    final code = (1000 + Random().nextInt(9000)).toString();

    await _db.runTransaction((tx) async {
      final fresh = FoodListing.fromFirestore(await tx.get(listingRef));
      if (!fresh.isAvailable || fresh.availablePortions < quantity) {
        throw Exception(
            'Not enough portions left — someone else may have just claimed one.');
      }

      tx.update(listingRef, {'claimedCount': fresh.claimedCount + quantity});

      tx.set(
        claimRef,
        PortionClaim(
          id: claimRef.id,
          listingId: listing.id,
          restaurantId: listing.restaurantId,
          userId: recipientId,
          quantity: quantity,
          status: 'claimed',
          claimedAt: DateTime.now(),
        ).toMap(),
      );

      tx.set(ref, {
        'code': code,
        'listingId': listing.id,
        'claimId': claimRef.id,
        'restaurantId': restaurant.id,
        'restaurantName': restaurant.name,
        'restaurantAddress': restaurant.address,
        'restaurantLat': restaurant.lat,
        'restaurantLng': restaurant.lng,
        'item': listing.item,
        'quantity': quantity,
        'recipientId': recipientId,
        'helperId': null,
        'status': RescueStatus.open,
        'approxLat': dropoff.lat == null
            ? null
            : double.parse(dropoff.lat!.toStringAsFixed(2)),
        'approxLng': dropoff.lng == null
            ? null
            : double.parse(dropoff.lng!.toStringAsFixed(2)),
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(_dropoffRef(ref.id), dropoff.toMap());
    });
    return ref.id;
  }

  // ── Status transitions ────────────────────────────────────────────────────

  // Shared guard: re-read inside the transaction, verify status and actor,
  // then apply the change with a server timestamp for this step.
  static Future<void> _transition({
    required String id,
    required List<String> from,
    required String to,
    required String stampField,
    required String Function(RescueRequest r)? actorError,
    Map<String, dynamic> extra = const {},
    void Function(Transaction tx, RescueRequest r, FoodListing? listing)? sideEffects,
    bool needsListing = false,
  }) {
    final ref = _col.doc(id);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('This request no longer exists.');
      final r = RescueRequest.fromFirestore(snap);
      if (!from.contains(r.status)) {
        throw Exception(_wrongStateMessage(r.status));
      }
      final err = actorError?.call(r);
      if (err != null && err.isNotEmpty) throw Exception(err);

      FoodListing? listing;
      if (needsListing) {
        final lSnap = await tx.get(_db.collection('foodListings').doc(r.listingId));
        if (lSnap.exists) listing = FoodListing.fromFirestore(lSnap);
      }

      sideEffects?.call(tx, r, listing);
      tx.update(ref, {
        'status': to,
        stampField: FieldValue.serverTimestamp(),
        ...extra,
      });
    });
  }

  static String _wrongStateMessage(String status) {
    switch (status) {
      case RescueStatus.claimed:
        return 'Another helper already accepted this request.';
      case RescueStatus.cancelled:
        return 'This request was cancelled.';
      case RescueStatus.completed:
        return 'This request is already completed.';
      default:
        return 'This step isn\'t available right now (status: $status).';
    }
  }

  // HELPER: open -> claimed
  static Future<void> accept(String id, String helperId) => _transition(
        id: id,
        from: [RescueStatus.open],
        to: RescueStatus.claimed,
        stampField: 'claimedAt',
        actorError: (r) =>
            r.recipientId == helperId ? 'You can\'t deliver your own request.' : '',
        extra: {'helperId': helperId},
      );

  // HELPER: claimed -> pickup_pending_restaurant
  static Future<void> markPickedUp(String id, String helperId) => _transition(
        id: id,
        from: [RescueStatus.claimed],
        to: RescueStatus.pickupPendingRestaurant,
        stampField: 'pickupReportedAt',
        actorError: (r) => r.helperId == helperId ? '' : 'This isn\'t your delivery.',
      );

  // RESTAURANT: pickup_pending_restaurant -> picked_up (final say).
  // The food has now left the restaurant, so the reserved portions move from
  // claimedCount to completedCount (same bookkeeping as completeDelivery).
  static Future<void> confirmHandoff(String id, String restaurantId) => _transition(
        id: id,
        from: [RescueStatus.pickupPendingRestaurant],
        to: RescueStatus.pickedUp,
        stampField: 'pickedUpAt',
        actorError: (r) =>
            r.restaurantId == restaurantId ? '' : 'This handoff isn\'t for your restaurant.',
        needsListing: true,
        sideEffects: (tx, r, listing) {
          if (listing != null) {
            final newCompleted = listing.completedCount + r.quantity;
            final newClaimed = listing.claimedCount - r.quantity;
            tx.update(_db.collection('foodListings').doc(r.listingId), {
              'completedCount': newCompleted,
              'claimedCount': newClaimed < 0 ? 0 : newClaimed,
              if (newCompleted >= listing.totalPortions) ...{
                'isCompleted': true,
                'completedAt': Timestamp.now(),
                'isAvailable': false,
              },
            });
          }
          tx.update(_db.collection('portionClaims').doc(r.claimId), {
            'status': 'completed',
            'completedAt': Timestamp.now(),
          });
        },
      );

  // RESTAURANT: "Didn't happen" — pickup_pending_restaurant -> claimed
  static Future<void> rejectHandoff(String id, String restaurantId) => _transition(
        id: id,
        from: [RescueStatus.pickupPendingRestaurant],
        to: RescueStatus.claimed,
        stampField: 'handoffRejectedAt',
        actorError: (r) =>
            r.restaurantId == restaurantId ? '' : 'This handoff isn\'t for your restaurant.',
      );

  // HELPER: picked_up -> delivered_pending_recipient
  static Future<void> markDelivered(String id, String helperId) => _transition(
        id: id,
        from: [RescueStatus.pickedUp],
        to: RescueStatus.deliveredPendingRecipient,
        stampField: 'deliveredAt',
        actorError: (r) => r.helperId == helperId ? '' : 'This isn\'t your delivery.',
      );

  // RECIPIENT: delivered_pending_recipient -> completed
  static Future<void> confirmReceived(String id, String recipientId) => _transition(
        id: id,
        from: [RescueStatus.deliveredPendingRecipient],
        to: RescueStatus.completed,
        stampField: 'completedAt',
        actorError: (r) => r.recipientId == recipientId ? '' : 'This isn\'t your request.',
      );

  // RECIPIENT: delivered_pending_recipient -> disputed
  static Future<void> reportNotReceived(String id, String recipientId) => _transition(
        id: id,
        from: [RescueStatus.deliveredPendingRecipient],
        to: RescueStatus.disputed,
        stampField: 'disputedAt',
        actorError: (r) => r.recipientId == recipientId ? '' : 'This isn\'t your request.',
      );

  // RECIPIENT: cancel before the food has left the restaurant. Returns the
  // reserved portions to the listing.
  static Future<void> cancel(String id, String recipientId) => _transition(
        id: id,
        from: [RescueStatus.open, RescueStatus.claimed],
        to: RescueStatus.cancelled,
        stampField: 'cancelledAt',
        actorError: (r) => r.recipientId == recipientId ? '' : 'This isn\'t your request.',
        needsListing: true,
        sideEffects: (tx, r, listing) {
          if (listing != null) {
            final newClaimed = listing.claimedCount - r.quantity;
            tx.update(_db.collection('foodListings').doc(r.listingId),
                {'claimedCount': newClaimed < 0 ? 0 : newClaimed});
          }
          tx.update(_db.collection('portionClaims').doc(r.claimId),
              {'status': 'cancelled'});
        },
      );

  // ── Streams ───────────────────────────────────────────────────────────────

  static List<RescueRequest> _newestFirst(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map(RescueRequest.fromFirestore).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }

  static Stream<RescueRequest?> requestStream(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? RescueRequest.fromFirestore(s) : null);

  static Stream<RescueDropoff?> dropoffStream(String id) => _dropoffRef(id)
      .snapshots()
      .map((s) => s.exists ? RescueDropoff.fromFirestore(s) : null);

  static Stream<List<RescueRequest>> openRequests() => _col
      .where('status', isEqualTo: RescueStatus.open)
      .snapshots()
      .map(_newestFirst);

  static Stream<List<RescueRequest>> helperRequests(String helperId) => _col
      .where('helperId', isEqualTo: helperId)
      .snapshots()
      .map(_newestFirst);

  static Stream<List<RescueRequest>> recipientRequests(String recipientId) => _col
      .where('recipientId', isEqualTo: recipientId)
      .snapshots()
      .map(_newestFirst);

  static Stream<List<RescueRequest>> pendingHandoffs(String restaurantId) => _col
      .where('restaurantId', isEqualTo: restaurantId)
      .where('status', isEqualTo: RescueStatus.pickupPendingRestaurant)
      .snapshots()
      .map(_newestFirst);

  // Same as pendingHandoffs, narrowed to one listing (restaurantId stays in
  // the query so the security rule can verify ownership).
  static Stream<List<RescueRequest>> pendingHandoffsForListing(
          String restaurantId, String listingId) =>
      _col
          .where('restaurantId', isEqualTo: restaurantId)
          .where('listingId', isEqualTo: listingId)
          .where('status', isEqualTo: RescueStatus.pickupPendingRestaurant)
          .snapshots()
          .map(_newestFirst);

  // ── Geocoding (optional) ──────────────────────────────────────────────────

  /// Best-effort lookup of a typed address. Returns null on any failure
  /// (API disabled, no network, not found) so the request can still be
  /// created with just the address text.
  static Future<({double lat, double lng})?> tryGeocode(String address) async {
    try {
      final coords = await LocationService.geocodeAddress(address)
          .timeout(const Duration(seconds: 8));
      if (coords == null) return null;
      return (lat: coords['lat']!, lng: coords['lng']!);
    } catch (_) {
      return null;
    }
  }

  // ── Directions ────────────────────────────────────────────────────────────

  /// Uses lat/lng when available, otherwise the address text.
  /// (0,0 is treated as "no coordinates" — that's the default for
  /// restaurants saved without a location.)
  static Uri directionsUri({
    double? lat,
    double? lng,
    required String address,
    bool apple = false,
  }) {
    final hasCoords = lat != null && lng != null && !(lat == 0 && lng == 0);
    final destination = hasCoords ? '$lat,$lng' : address;
    if (apple) {
      return Uri.https('maps.apple.com', '/', {
        'daddr': destination,
        'dirflg': 'd',
      });
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
  }

  static Future<bool> launchDirections({
    double? lat,
    double? lng,
    required String address,
    bool apple = false,
  }) =>
      launchUrl(
        directionsUri(lat: lat, lng: lng, address: address, apple: apple),
        mode: LaunchMode.externalApplication,
      );

  static bool get canUseAppleMaps =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}
