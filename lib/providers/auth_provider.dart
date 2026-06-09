import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/restaurant.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _firebaseUser;
  AppUser? _appUser;
  bool _loading = true;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get loading => _loading;
  bool get isLoggedIn => _firebaseUser != null;
  String? get role => _appUser?.role;

  AuthProvider() {
    FirebaseService.authStateChanges.listen(_onAuthChange);
  }

  void _onAuthChange(User? user) {
    _firebaseUser = user;
    if (user != null) {
      FirebaseService.userStream(user.uid).listen((appUser) {
        _appUser = appUser;
        _loading = false;
        notifyListeners();
      });
    } else {
      _appUser = null;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signInRestaurant(String email, String password) async {
    await FirebaseService.signIn(email, password);
  }

  Future<void> signUpRestaurant({
    required String email,
    required String password,
    required String restaurantName,
    required String address,
    required String contactInfo,
    required String hours,
    required double lat,
    required double lng,
  }) async {
    final cred = await FirebaseService.signUp(email, password);
    final uid = cred.user!.uid;

    final userDoc = AppUser(
      id: uid,
      email: email,
      role: 'restaurant',
      allergies: [],
      phone: contactInfo,
    );
    await FirebaseService.createUserDoc(userDoc);

    await FirebaseService.createRestaurant(
      Restaurant(
        id: '',
        name: restaurantName,
        address: address,
        lat: lat,
        lng: lng,
        contactInfo: contactInfo,
        hoursOfOperation: hours,
        isVerified: false,
        ownerId: uid,
      ),
    );
  }

  Future<void> signInUser(String email, String password) async {
    await FirebaseService.signIn(email, password);
  }

  Future<void> signUpUser(String email, String password) async {
    final cred = await FirebaseService.signUp(email, password);
    final uid = cred.user!.uid;
    await FirebaseService.createUserDoc(
      AppUser(
        id: uid,
        email: email,
        role: 'user',
        allergies: [],
        phone: '',
      ),
    );
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
  }
}
