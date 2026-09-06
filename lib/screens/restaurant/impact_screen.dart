import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/food_listing.dart';
import '../../models/restaurant.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/tax_receipt_service.dart';
import '../../theme.dart';
import '../../widgets/good_samaritan_info_card.dart';

class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  List<FoodListing> _allListings = [];
  StreamSubscription<List<FoodListing>>? _sub;
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final restaurantId =
        context.read<RestaurantProvider>().myRestaurant?.id;
    if (restaurantId != null && restaurantId.isNotEmpty) {
      _sub = FirebaseService.allListingsByRestaurant(restaurantId).listen((list) {
        if (mounted) setState(() => _allListings = list);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = context.watch<RestaurantProvider>().myRestaurant;
    if (restaurant == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final lastYearRevenue = restaurant.lastYearRevenue ?? 0.0;
    final projectedGrowth = restaurant.projectedGrowth ?? 0.0;
    final projectedRevenue = lastYearRevenue * (1 + projectedGrowth / 100);

    double totalDonationValue = 0;
    int totalPeopleFed = 0;
    for (final l in _allListings) {
      totalDonationValue += (l.cost ?? 0) * l.completedCount;
      totalPeopleFed += l.completedCount;
    }

    final donationPct =
        projectedRevenue > 0 ? (totalDonationValue / projectedRevenue * 100) : 0.0;
    final floorTarget = projectedRevenue * 0.01;
    final progressToFloor =
        floorTarget > 0 ? (totalDonationValue / floorTarget) : 0.0;
    final Color progressColor = progressToFloor >= 1.0
        ? Colors.green
        : progressToFloor >= 0.5
            ? AppColors.warning
            : Colors.red.shade400;

    return Scaffold(
      appBar: AppBar(title: const Text('Impact Dashboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const GoodSamaritanInfoCard(),
          const SizedBox(height: 16), 
          if (!restaurant.calculateTaxDeduction)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tax deduction tracking is turned off for this restaurant. '
                      'Enable it under My Info to see revenue and 1%-floor progress.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          if (restaurant.calculateTaxDeduction) ...[
            // ── Revenue context ──────────────────────────────────────────
            _SectionHeader(icon: Icons.monetization_on, label: 'Revenue Overview'),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'This Year\'s Projected Revenue',
                      value: _currency.format(projectedRevenue),
                      icon: Icons.trending_up,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: '1% of Projected Revenue',
                      value: _currency.format(floorTarget),
                      subtitle: 'Minimum to qualify for tax deduction',
                      icon: Icons.volunteer_activism,
                      iconColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Circular progress ────────────────────────────────────────
            _SectionHeader(
                icon: Icons.pie_chart_outline,
                label: 'Donation Value as % of Revenue'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: progressToFloor.clamp(0.0, 1.0),
                          strokeWidth: 16,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(progressColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progressToFloor * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                          Text(
                            'of ${_currency.format(floorTarget)} goal',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 1% floor status banner ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: donationPct >= 1.0
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: donationPct >= 1.0
                      ? Colors.green.shade300
                      : Colors.orange.shade400,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    donationPct >= 1.0
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: donationPct >= 1.0
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: donationPct >= 1.0
                        ? Text(
                            'You\'ve met the 1% charitable deduction floor! '
                            'Your food donations qualify for a tax deduction.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green.shade800,
                            ),
                          )
                        : Text(
                            'You need ${_currency.format((projectedRevenue * 0.01) - totalDonationValue)} '
                            'more to reach 1% of your revenue.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange.shade900,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],

          // ── Donation value (always shown) ────────────────────────────
          _SectionHeader(icon: Icons.people, label: 'Food Donation Impact'),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Total Donation Value',
                    value: _currency.format(totalDonationValue),
                    icon: Icons.volunteer_activism,
                    iconColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            const Text('Orders Completed',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ]),
                          Text(
                            totalPeopleFed.toString(),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          const Divider(height: 16),
                          Row(children: [
                            Icon(Icons.people,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            const Text('People Fed',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ]),
                          Text(
                            totalPeopleFed.toString(),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _downloadReceipt(restaurant),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download Donation Summary (for your accountant)'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt(Restaurant restaurant) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime(DateTime.now().year, 1, 1),
        end: DateTime.now(),
      ),
    );
    if (range == null || !mounted) return;

    final bytes = await TaxReceiptService.generateAnnualReceipt(
      restaurant: restaurant,
      completedListings: _allListings,
      periodStart: range.start,
      periodEnd: range.end,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
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
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
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

