import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/user_provider.dart';
import '../theme.dart';
import 'role_select_screen.dart';
import 'restaurant/restaurant_home_screen.dart';
import 'user/user_home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
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

    if (!auth.isLoggedIn) {
      return const RoleSelectScreen();
    }

    // Kick off data listeners after login
    final role = auth.role;
    final uid = auth.firebaseUser!.uid;

    if (role == 'restaurant') {
      // listenToMyRestaurant is called inside RestaurantHomeScreen.initState
      return const RestaurantHomeScreen();
    }

    // User role — start user data listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().listenToUser(uid);
    });

    return const UserHomeScreen();
  }
}
