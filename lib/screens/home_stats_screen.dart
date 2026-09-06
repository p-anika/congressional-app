import 'package:flutter/material.dart';
import '../theme.dart';
import 'role_select_screen.dart';

class HomeStatsScreen extends StatelessWidget {
  const HomeStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Icon(Icons.eco_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('FoodRescue',
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.accent)),
            const SizedBox(height: 6),
            const Text(
              'Every day, good food goes to waste while people nearby go hungry. '
              'Here\'s why that matters.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 28),
            const _StatCard(
              icon: Icons.home_outlined,
              value: '771,480',
              label: 'people experienced homelessness on a single night in January 2024',
              source: 'U.S. Dept. of Housing & Urban Development, 2024 Annual Homeless '
                  'Assessment Report \u2014 the highest count on record, up 18% from 2023.',
            ),
            const SizedBox(height: 16),
            const _StatCard(
              icon: Icons.no_meals_outlined,
              value: '13.7%',
              label: 'of U.S. households (18.3 million) were food insecure at some point in 2024',
              source: 'USDA Economic Research Service, Household Food Security in the '
                  'U.S., 2024 \u2014 the highest rate in a decade.',
            ),
            const SizedBox(height: 16),
            const _StatCard(
              icon: Icons.delete_outline,
              value: '30\u201340%',
              label: 'of the entire U.S. food supply goes to waste every year',
              source: 'USDA & EPA estimate \u2014 much of it edible food discarded by '
                  'restaurants, stores, and homes.',
            ),
            const SizedBox(height: 28),
            const Text(
              'FoodRescue connects restaurants with surplus food to people who need it, '
              'with volunteers helping bridge the gap.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
              ),
              child: const Text('Get Started'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Figures reflect the most recent published reports as of each source above '
              'and will change as new data is released.',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(source, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}