import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import 'role_select_screen.dart';
import 'restaurant/restaurant_home_screen.dart';
import 'user/user_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Cache the future per UID to prevent re-fetching on every rebuild
  String? _cachedUid;
  Future<String?>? _roleFuture;

  Future<String?> _fetchRole(String uid) async {
    try {
      final user = await FirebaseService.getUserDocOnce(uid);
      return user?.role;
    } catch (e) {
      debugPrint('SplashScreen: role fetch error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        final user = authSnap.data;
        if (user == null) {
          return const RoleSelectScreen();
        }

        // Cache the future so rebuilds don't re-trigger the GET
        if (_cachedUid != user.uid) {
          _cachedUid = user.uid;
          _roleFuture = _fetchRole(user.uid);
        }

        return FutureBuilder<String?>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return _loadingScreen();
            }
            final role = roleSnap.data;
            if (role == 'restaurant') return const RestaurantHomeScreen();
            if (role == 'user') return const UserHomeScreen();
            return const RoleSelectScreen();
          },
        );
      },
    );
  }

  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'FoodRescue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
