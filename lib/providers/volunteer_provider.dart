import 'dart:async';
import 'package:flutter/material.dart';
import '../models/volunteer.dart';
import '../services/firebase_service.dart';

class VolunteerProvider extends ChangeNotifier {
  Volunteer? _myVolunteer;
  StreamSubscription? _volunteerSub;

  Volunteer? get myVolunteer => _myVolunteer;

  void listenToMyVolunteer(String uid) {
    _volunteerSub?.cancel();
    _volunteerSub = FirebaseService.volunteerStream(uid).listen((v) {
      _myVolunteer = v;
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
    super.dispose();
  }
}
