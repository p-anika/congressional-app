import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/firebase_service.dart';

class RestaurantProvider extends ChangeNotifier {
  Restaurant? _myRestaurant;
  List<Restaurant> _verifiedRestaurants = [];

  Restaurant? get myRestaurant => _myRestaurant;
  List<Restaurant> get verifiedRestaurants => _verifiedRestaurants;

  void listenToMyRestaurant(String ownerId) {
    FirebaseService.restaurantByOwner(ownerId).listen((r) {
      _myRestaurant = r;
      notifyListeners();
    });
  }

  void listenToVerifiedRestaurants() {
    FirebaseService.verifiedRestaurantsStream().listen((list) {
      _verifiedRestaurants = list;
      notifyListeners();
    });
  }

  Future<void> updateMyRestaurant(Map<String, dynamic> data) async {
    if (_myRestaurant == null) return;
    await FirebaseService.updateRestaurant(_myRestaurant!.id, data);
  }
}
