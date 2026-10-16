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
              'ShareMeal',
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
              'Everyone deserves a meal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 22),

            // ── Statistics (full text, no tapping required) ──────────
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.home_outlined,
                    value: '771,480',
                    label: 'unhoused people in the U.S. on a single night (+18% vs 2023)',
                    source: 'HUD 2024 AHAR Report',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.no_meals_outlined,
                    value: '13.7%',
                    label: 'of U.S. households are food insecure, totalling to 18.3M homes',
                    source: 'USDA ERS 2024',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.delete_outline,
                    value: '30–40%',
                    label: 'of the U.S. food supply is wasted yearly',
                    source: 'USDA & EPA Estimates',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Mission statement ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'ShareMeal connects restaurants with surplus food to people experiencing '
                'hunger, with volunteers bridging the gap between them. Restaurants list food '
                'that would otherwise go to waste, people in need can browse and claim what\'s '
                'available nearby, and volunteers step in to deliver to those who can\'t easily '
                'reach a restaurant themselves. Our goal is to reduce food waste and food '
                'insecurity in local communities simultaneously — one meal at a time.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 24),

            // ── Role selection ────────────────────────────────────────
            const Text(
              'I am a…',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String source;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(source, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
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