import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/delivery_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../theme.dart';

class VolunteerImpactScreen extends StatelessWidget {
  const VolunteerImpactScreen({super.key});

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0 min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VolunteerProvider>();
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('My Impact')),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<DeliveryRequest>>(
              stream: context.read<DeliveryProvider>().deliveryHistory(uid),
              builder: (context, snap) {
                final deliveries = snap.data ?? [];

                int totalMinutes = 0;
                int totalMealsDelivered = 0;
                for (final d in deliveries) {
                  totalMealsDelivered += d.quantity;
                  if (d.acceptedAt != null && d.deliveredAt != null) {
                    totalMinutes +=
                        d.deliveredAt!.difference(d.acceptedAt!).inMinutes;
                  }
                }

                return ListView(
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
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.volunteerPrimary,
                              label: 'Time Spent Delivering',
                              value: _formatDuration(totalMinutes),
                              subtitle: deliveries.isEmpty
                                  ? 'Complete a delivery to start tracking.'
                                  : 'Across ${deliveries.length} delivery${deliveries.length == 1 ? '' : 'ies'}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.delivery_dining_outlined,
                              iconColor: AppColors.accent,
                              label: 'Meals Delivered',
                              value: totalMealsDelivered.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Delivered Meals ──────────────────────────────────
                    const Text('Delivered Meals',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (deliveries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No deliveries completed yet.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ...deliveries.map((d) => _DeliveredMealCard(delivery: d)),

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
                              leading:
                                  const Icon(Icons.check_circle, color: Colors.green),
                              title: Text(p.item),
                              subtitle: Text(
                                  '${p.purchasedAt.month}/${p.purchasedAt.day}/${p.purchasedAt.year}'),
                              trailing: Text(currency.format(p.pricePaid),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          )),
                  ],
                );
              },
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
                    fontSize: 22,
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

class _DeliveredMealCard extends StatelessWidget {
  final DeliveryRequest delivery;
  const _DeliveredMealCard({required this.delivery});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String? _durationLabel() {
    if (delivery.acceptedAt == null || delivery.deliveredAt == null) return null;
    final minutes =
        delivery.deliveredAt!.difference(delivery.acceptedAt!).inMinutes;
    if (minutes < 60) return '$minutes min trip';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hours hr trip' : '$hours hr $rem min trip';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _durationLabel();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.delivery_dining, color: Colors.green),
        title: Text('${delivery.quantity} × ${delivery.item}'),
        subtitle: Text(
          '${delivery.restaurantName} · Delivered ${_formatDate(delivery.deliveredAt)}'
          '${duration != null ? ' · $duration' : ''}',
        ),
        isThreeLine: false,
      ),
    );
  }
}