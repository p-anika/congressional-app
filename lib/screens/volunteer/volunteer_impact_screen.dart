import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../theme.dart';

class VolunteerImpactScreen extends StatelessWidget {
  const VolunteerImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VolunteerProvider>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('My Impact')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.volunteer_activism,
                    iconColor: Colors.green,
                    label: 'Money Donated',
                    value: currency.format(provider.totalMoneyDonated),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.restaurant_menu,
                    iconColor: AppColors.primary,
                    label: 'Meals Bought',
                    value: provider.totalMealsBought.toString(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.textSecondary,
            label: 'Time Spent Delivering',
            value: 'Coming soon',
            subtitle: 'Will track once delivery requests are added.',
          ),
          const SizedBox(height: 24),
          const Text('Purchase History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (provider.myPurchases.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No purchases yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...provider.myPurchases.map((p) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(p.item),
                    subtitle: Text(
                        '${p.purchasedAt.month}/${p.purchasedAt.day}/${p.purchasedAt.year}'),
                    trailing: Text(currency.format(p.pricePaid),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}