import 'package:flutter/material.dart';
import '../theme.dart';
import 'restaurant/restaurant_auth_screen.dart';
import 'user/user_auth_screen.dart';
import 'volunteer/volunteer_auth_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            // ── Header ──────────────────────────────────────────────
            const Icon(Icons.eco_outlined, size: 52, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text(
              'FoodRescue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connecting surplus food with people who need it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 22),

            // ── Statistics row ────────────────────────────────────────
            Row(
              children: const [
                Expanded(
                  child: _StatBox(
                    icon: Icons.home_outlined,
                    value: '771,480',
                    label: 'people homeless on a single night (Jan. 2024)',
                    source: 'U.S. Dept. of Housing & Urban Development, 2024 '
                        'Annual Homeless Assessment Report — the highest '
                        'count on record, up 18% from 2023.',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    icon: Icons.no_meals_outlined,
                    value: '13.7%',
                    label: 'of U.S. households food insecure in 2024',
                    source: 'USDA Economic Research Service, Household Food '
                        'Security in the U.S., 2024 — the highest rate in a '
                        'decade (18.3 million households).',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    icon: Icons.delete_outline,
                    value: '30–40%',
                    label: 'of the U.S. food supply wasted every year',
                    source: 'USDA & EPA estimate — much of it edible food '
                        'discarded by restaurants, stores, and homes.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap a statistic for its source.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 28),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 24),

            // ── Role selection ────────────────────────────────────────
            const Text(
              'I am a…',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.store_outlined,
              title: 'Restaurant',
              subtitle: 'List surplus food for pickup',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RestaurantAuthScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _RoleCard(
              icon: Icons.person_outline,
              title: 'Person in Need of Food',
              subtitle: 'Find free meals near me',
              color: AppColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserAuthScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _RoleCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Volunteer',
              subtitle: 'Help deliver food and give back',
              color: AppColors.volunteerPrimary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VolunteerAuthScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String source;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.source,
  });

  void _showSource(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(value),
        content: Text(source, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showSource(context),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                radius: 28,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}