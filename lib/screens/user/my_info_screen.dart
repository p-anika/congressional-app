import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme.dart';
import '../../widgets/allergen_chips.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  bool _refreshingLocation = false;

  Future<void> _refreshLocation() async {
    setState(() => _refreshingLocation = true);
    await context.read<UserProvider>().refreshLocation();
    if (mounted) setState(() => _refreshingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Account info ─────────────────────────────────────────
                const Text('Account',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email,
                ),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user.phone.isEmpty ? 'Not set' : user.phone,
                ),
                const SizedBox(height: 24),

                // ── Location ─────────────────────────────────────────────
                const Text('Location',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userProvider.userLat != null
                            ? '${userProvider.userLat!.toStringAsFixed(4)}, '
                                '${userProvider.userLng!.toStringAsFixed(4)}'
                            : 'Location not set',
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _refreshingLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : OutlinedButton.icon(
                            onPressed: _refreshLocation,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Dietary restrictions ──────────────────────────────────
                const Text('Dietary Restrictions / Allergies',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Listings with your allergens will show a warning.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                AllergenSelector(
                  selected: user.allergies,
                  onChanged: (updated) =>
                      context.read<UserProvider>().updateAllergies(updated),
                ),
              ],
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
