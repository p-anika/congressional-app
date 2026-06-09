import 'package:flutter/material.dart';
import '../models/food_listing.dart';
import '../services/firebase_service.dart';

class FoodListingProvider extends ChangeNotifier {
  List<FoodListing> _myListings = [];
  List<FoodListing> _allListings = [];

  List<FoodListing> get myListings => _myListings;
  List<FoodListing> get allListings => _allListings;

  List<FoodListing> listingsForRestaurant(String restaurantId) {
    return _allListings.where((l) => l.restaurantId == restaurantId).toList();
  }

  void listenToMyListings(String restaurantId) {
    FirebaseService.listingsByRestaurant(restaurantId).listen((list) {
      _myListings = list;
      notifyListeners();
    });
  }

  void listenToAllListings() {
    FirebaseService.allActiveListings().listen((list) {
      _allListings = list;
      notifyListeners();
    });
  }

  Future<void> addListing({
    required String restaurantId,
    required String item,
    required String amount,
    required int feedsPeople,
    required List<String> allergens,
    required List<String> contains,
    DateTime? expiresAt,
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
    );
    await FirebaseService.addFoodListing(listing);
  }

  Future<void> toggleAvailability(FoodListing listing) async {
    await FirebaseService.updateFoodListing(
      listing.id,
      {'isAvailable': !listing.isAvailable},
    );
  }

  Future<void> deleteListing(String id) async {
    await FirebaseService.deleteFoodListing(id);
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await FirebaseService.updateFoodListing(id, data);
  }
}
