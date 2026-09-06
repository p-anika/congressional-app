import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/restaurant.dart';
import '../models/volunteer.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _firebaseUser;
  AppUser? _appUser;
  bool _loading = true;
  bool _disposed = false;
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get loading => _loading;
  bool get isLoggedIn => _firebaseUser != null;
  String? get role => _appUser?.role;

  AuthProvider() {
    _authSub = FirebaseService.authStateChanges.listen(_onAuthChange);
  }

  void _onAuthChange(User? user) {
    _userSub?.cancel();
    _userSub = null;
    _firebaseUser = user;
    if (user != null) {
      _loading = true;
      notifyListeners();
      _resolveUserDoc(user.uid);
    } else {
      _appUser = null;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _resolveUserDoc(String uid) async {
    // One-time GET resolves immediately without the web stream's initial null
    try {
      final appUser = await FirebaseService.getUserDocOnce(uid);
      if (_disposed) return;
      if (appUser != null) {
        _appUser = appUser;
        _loading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider: GET error: $e');
      if (_disposed) return;
      _loading = false;
      notifyListeners();
      return;
    }

    // Stream subscription for real-time updates and signup-race recovery
    // (doc may not exist yet at GET time when signup just created the auth user)
    _userSub = FirebaseService.userStream(uid).listen((appUser) {
      if (_disposed) return;
      if (appUser != null) {
        _appUser = appUser;
        if (_loading) _loading = false;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('AuthProvider: stream error: $e');
      if (_disposed || !_loading) return;
      _loading = false;
      notifyListeners();
    });

    // Safety net: force-resolve after 8 s so UI never gets permanently stuck
    Future.delayed(const Duration(seconds: 8), () {
      if (_disposed || !_loading) return;
      debugPrint('AuthProvider: safety timeout — forcing _loading = false');
      _loading = false;
      notifyListeners();
    });
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
    double lastYearRevenue = 0.0,
    double projectedGrowth = 0.0,
    bool calculateTaxDeduction = true,
    String? businessLicenseNumber,
    String? stateRegistrationNumber,
    String? foodHandlerPermitNumber,
  }) async {
    final cred = await FirebaseService.signUp(email, password);
    final uid = cred.user!.uid;

    await FirebaseService.createUserDoc(AppUser(
      id: uid,
      email: email,
      role: 'restaurant',
      allergies: [],
      phone: contactInfo,
    ));

    await FirebaseService.createRestaurant(Restaurant(
      id: '',
      name: restaurantName,
      address: address,
      lat: lat,
      lng: lng,
      contactInfo: contactInfo,
      hoursOfOperation: hours,
      isVerified: false,
      ownerId: uid,
      lastYearRevenue: lastYearRevenue,
      projectedGrowth: projectedGrowth,
      calculateTaxDeduction: calculateTaxDeduction,
      businessLicenseNumber: businessLicenseNumber,
      stateRegistrationNumber: stateRegistrationNumber,
      foodHandlerPermitNumber: foodHandlerPermitNumber,
    ));
  }

  Future<void> signInUser(String email, String password) async {
    await FirebaseService.signIn(email, password);
  }

  Future<void> signUpUser(String email, String password,
      {String phone = ''}) async {
    final cred = await FirebaseService.signUp(email, password);
    final uid = cred.user!.uid;
    await FirebaseService.createUserDoc(AppUser(
      id: uid,
      email: email,
      role: 'user',
      allergies: [],
      phone: phone,
    ));
  }

  Future<void> signInVolunteer(String email, String password) async {
    await FirebaseService.signIn(email, password);
  }

  Future<void> signUpVolunteer({
    required String email,
    required String password,
    required String name,
    required String phone,
    String organization = '',
  }) async {
    final cred = await FirebaseService.signUp(email, password);
    final uid = cred.user!.uid;

    await FirebaseService.createUserDoc(AppUser(
      id: uid,
      email: email,
      role: 'volunteer',
      allergies: [],
      phone: phone,
    ));

    await FirebaseService.createVolunteerDoc(Volunteer(
      id: uid,
      name: name,
      email: email,
      phone: phone,
      organization: organization,
      isApproved: false, // reviewed by you later, like restaurant isVerified
    ));
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
