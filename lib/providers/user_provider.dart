import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class UserProvider extends ChangeNotifier {
  AppUser? _user;
  double? _userLat;
  double? _userLng;
  StreamSubscription? _userSub;

  AppUser? get user => _user;
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  List<String> get allergies => _user?.allergies ?? [];

  void listenToUser(String uid) {
    _userSub?.cancel();
    _userSub = FirebaseService.userStream(uid).listen((u) {
      _user = u;
      if (u?.location != null) {
        _userLat = u!.location!.latitude;
        _userLng = u.location!.longitude;
      }
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> refreshLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null || _user == null) return;
    _userLat = pos.latitude;
    _userLng = pos.longitude;
    await FirebaseService.updateUserDoc(_user!.id, {
      'location': GeoPoint(pos.latitude, pos.longitude),
    });
    notifyListeners();
  }

  Future<void> updateAllergies(List<String> allergies) async {
    if (_user == null) return;
    await FirebaseService.updateUserDoc(_user!.id, {'allergies': allergies});
  }

  Future<void> updatePhone(String phone) async {
    if (_user == null) return;
    await FirebaseService.updateUserDoc(_user!.id, {'phone': phone});
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
