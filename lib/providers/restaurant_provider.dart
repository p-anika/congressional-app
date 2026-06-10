import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/firebase_service.dart';

class RestaurantProvider extends ChangeNotifier {
  Restaurant? _myRestaurant;
  List<Restaurant> _verifiedRestaurants = [];
  StreamSubscription? _myRestaurantSub;
  StreamSubscription? _verifiedSub;

  Restaurant? get myRestaurant => _myRestaurant;
  List<Restaurant> get verifiedRestaurants => _verifiedRestaurants;

  void listenToMyRestaurant(String ownerId) {
    _myRestaurantSub?.cancel();
    _myRestaurantSub =
        FirebaseService.restaurantByOwner(ownerId).listen((r) {
      _myRestaurant = r;
      notifyListeners();
    }, onError: (_) {});
  }

  void listenToVerifiedRestaurants() {
    _verifiedSub?.cancel();
    _verifiedSub =
        FirebaseService.verifiedRestaurantsStream().listen((list) {
      _verifiedRestaurants = list;
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> updateMyRestaurant(Map<String, dynamic> data) async {
    if (_myRestaurant == null) return;
    await FirebaseService.updateRestaurant(_myRestaurant!.id, data);
  }

  @override
  void dispose() {
    _myRestaurantSub?.cancel();
    _verifiedSub?.cancel();
    super.dispose();
  }
}
