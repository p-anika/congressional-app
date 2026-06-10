import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/food_listing_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/user_provider.dart';
import 'map_screen.dart';
import 'list_screen.dart';
import 'my_info_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const ListScreen(),
    const MyInfoScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      context.read<UserProvider>().listenToUser(uid);
    }
    context.read<RestaurantProvider>().listenToVerifiedRestaurants();
    context.read<FoodListingProvider>().listenToAllListings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'List',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'My Info',
          ),
        ],
      ),
    );
  }
}
