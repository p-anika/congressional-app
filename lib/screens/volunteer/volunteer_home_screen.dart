import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../theme.dart';
import 'volunteer_buy_meals_screen.dart';
import 'volunteer_impact_screen.dart';
import 'volunteer_info_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    VolunteerBuyMealsScreen(),
    VolunteerImpactScreen(),
    VolunteerInfoScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid != null) {
      context.read<VolunteerProvider>().listenToMyVolunteer(uid);
      context.read<VolunteerProvider>().listenToMyPurchases(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteer = context.watch<VolunteerProvider>().myVolunteer;

    return Theme(
      data: buildVolunteerTheme(),
      child: Scaffold(
        body: Column(
          children: [
            if (volunteer != null && !volunteer.isApproved)
              MaterialBanner(
                backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                leading:
                    const Icon(Icons.pending_outlined, color: AppColors.warning),
                content: const Text(
                  'Your volunteer account is pending review. '
                  'Some features may be limited until approved.',
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
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: 'Buy Meals',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Impact',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'My Info',
            ),
          ],
        ),
      ),
    );
  }
}