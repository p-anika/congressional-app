import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../theme.dart';
import 'restaurant_listings_screen.dart';
import 'restaurant_profile_screen.dart';

class RestaurantHomeScreen extends StatefulWidget {
  const RestaurantHomeScreen({super.key});

  @override
  State<RestaurantHomeScreen> createState() => _RestaurantHomeScreenState();
}

class _RestaurantHomeScreenState extends State<RestaurantHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    RestaurantListingsScreen(),
    RestaurantProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid != null) {
      context.read<RestaurantProvider>().listenToMyRestaurant(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = context.watch<RestaurantProvider>().myRestaurant;

    return Scaffold(
      body: Column(
        children: [
          if (restaurant != null && !restaurant.isVerified)
            MaterialBanner(
              backgroundColor: AppColors.warning.withValues(alpha: 0.15),
              leading: const Icon(Icons.pending_outlined, color: AppColors.warning),
              content: const Text(
                'Your restaurant is pending manual verification. '
                'Listings will be visible once approved.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Listings',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
