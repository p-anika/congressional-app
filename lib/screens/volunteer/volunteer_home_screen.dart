import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../theme.dart';
import '../role_select_screen.dart';
import '../volunteer/volunteer_buy_meals_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
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
    final auth = context.watch<AuthProvider>();

    return Theme(
      data: buildVolunteerTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Volunteer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (volunteer != null && !volunteer.isApproved)
              MaterialBanner(
                backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                leading: const Icon(Icons.pending_outlined, color: AppColors.warning),
                content: const Text(
                  'Your volunteer account is pending review. '
                  'Some features may be limited until approved.',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                actions: const [SizedBox.shrink()],
              ),
            Expanded( // const Expanded () ??
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Buy a Meal to Donate'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VolunteerBuyMealsScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}