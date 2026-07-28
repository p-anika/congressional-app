import 'dart:async';
import 'package:flutter/material.dart';
import '../models/food_listing.dart';
import '../services/firebase_service.dart';

class FoodListingProvider extends ChangeNotifier {
  List<FoodListing> _myListings = [];
  List<FoodListing> _allListings = [];
  StreamSubscription? _myListingsSub;
  StreamSubscription? _allListingsSub;

  List<FoodListing> get myListings => _myListings;
  List<FoodListing> get allListings => _allListings;

  List<FoodListing> listingsForRestaurant(String restaurantId) {
    return _allListings.where((l) => l.restaurantId == restaurantId).toList();
  }

  void listenToMyListings(String restaurantId) {
    _myListingsSub?.cancel();
    // Restaurant management view shows only active (isAvailable=true) listings.
    // Soft-deleting sets isAvailable=false which removes the item from this stream.
    _myListingsSub =
        FirebaseService.listingsByRestaurant(restaurantId).listen((list) {
      _myListings = list;
      notifyListeners();
    }, onError: (_) {});
  }

  void listenToAllListings() {
    _allListingsSub?.cancel();
    _allListingsSub = FirebaseService.allActiveListings().listen((list) {
      _allListings = list;
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> addListing({
    required String restaurantId,
    required String item,
    required String amount,
    required int feedsPeople,
    required List<String> allergens,
    required List<String> contains,
    DateTime? expiresAt,
    double? cost,
    double? price,
  }) async {
    final listing = FoodListing(
      id: '',
      restaurantId: restaurantId,
      item: item,
      amount: amount,
      feedsPeople: feedsPeople,
      allergens: allergens,
      contains: contains,
      isAvailable: true,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      cost: cost,
      price: price,
    );
    await FirebaseService.addFoodListing(listing);
  }

  Future<void> toggleAvailability(FoodListing listing) async {
    await FirebaseService.updateFoodListing(
      listing.id,
      {'isAvailable': !listing.isAvailable},
    );
  }

  Future<void> claimPortions(FoodListing listing, String userId, int quantity) async {
    await FirebaseService.claimPortions(
        listing: listing, userId: userId, quantity: quantity);
  }

  Future<void> purchasePortions(
    FoodListing listing,
    String buyerId,
    int quantity, {
    bool isSelfPurchase = false,
  }) async {
    await FirebaseService.purchasePortions(
      listing: listing,
      buyerId: buyerId,
      quantity: quantity,
      isSelfPurchase: isSelfPurchase,
    );
  }

  Future<void> deleteListing(String id) async {
    await FirebaseService.deleteFoodListing(id);
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await FirebaseService.updateFoodListing(id, data);
  }

  @override
  void dispose() {
    _myListingsSub?.cancel();
    _allListingsSub?.cancel();
    super.dispose();
  }
}
