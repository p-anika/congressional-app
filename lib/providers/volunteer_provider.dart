import 'dart:async';
import 'package:flutter/material.dart';
import '../models/volunteer.dart';
import '../models/meal_purchase.dart';
import '../services/firebase_service.dart';

class VolunteerProvider extends ChangeNotifier {
  Volunteer? _myVolunteer;
  List<MealPurchase> _myPurchases = [];
  StreamSubscription? _volunteerSub;
  StreamSubscription? _purchasesSub;

  Volunteer? get myVolunteer => _myVolunteer;
  List<MealPurchase> get myPurchases => _myPurchases;
  double get totalMoneyDonated => _myPurchases.fold(0.0, (sum, p) => sum + p.pricePaid);
  int get totalMealsBought => _myPurchases.length;

  void listenToMyVolunteer(String uid) {
    _volunteerSub?.cancel();
    _volunteerSub = FirebaseService.volunteerStream(uid).listen((v) {
      _myVolunteer = v;
      notifyListeners();
    }, onError: (_) {});
  }

  void listenToMyPurchases(String uid) {
    _purchasesSub?.cancel();
    _purchasesSub = FirebaseService.purchasesByVolunteer(uid).listen((list) {
      _myPurchases = list;
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> updateMyVolunteer(Map<String, dynamic> data) async {
    if (_myVolunteer == null) return;
    await FirebaseService.updateVolunteerDoc(_myVolunteer!.id, data);
  }

  @override
  void dispose() {
    _volunteerSub?.cancel();
    _purchasesSub?.cancel();
    super.dispose();
  }
}