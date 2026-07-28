import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../providers/food_listing_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';
import '../../widgets/quantity_dialog.dart';

class VolunteerBuyMealsScreen extends StatefulWidget {
  const VolunteerBuyMealsScreen({super.key});

  @override
  State<VolunteerBuyMealsScreen> createState() =>
      _VolunteerBuyMealsScreenState();
}

class _VolunteerBuyMealsScreenState extends State<VolunteerBuyMealsScreen> {
  List<FoodListing> _listings = [];
  StreamSubscription<List<FoodListing>>? _sub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseService.purchasableListingsStream().listen(
      (list) {
        if (mounted) setState(() { _listings = list; _error = null; });
      },
      onError: (e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _confirmBuy(FoodListing listing) async {
    final volunteer = context.read<VolunteerProvider>().myVolunteer;
    if (volunteer == null || !volunteer.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your volunteer account must be approved before buying meals.'),
      ));
      return;
    }

    final qty = await showQuantityDialog(context,
        title: 'How many portions to sponsor?',
        max: listing.purchasablePortionsRemaining);
    if (qty == null) return;

    final total = (listing.price ?? 0) * qty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Text(
          'Sponsor $qty portion${qty == 1 ? '' : 's'} of "${listing.item}" for '
          '\$${total.toStringAsFixed(2)} and donate it to someone in need?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm & Donate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    try {
      await context
          .read<FoodListingProvider>()
          .purchasePortions(listing, uid, qty, isSelfPurchase: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You sponsored $qty portion${qty == 1 ? '' : 's'} of "${listing.item}". Thank you!'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy a Meal to Donate')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text('Error loading meals: $_error',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Expanded(
            child: _listings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No meals available for purchase right now.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _listings.length,
                    itemBuilder: (ctx, i) {
                      final l = _listings[i];
                      final total = (l.price ?? 0) * l.feedsPeople;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.item,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Feeds ${l.feedsPeople} · ${l.amount}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 13)),
                              if (l.allergens.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Contains: ${l.allergens.join(', ')}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary, fontSize: 12)),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '\$${l.price!.toStringAsFixed(2)}/portion · ${l.purchasablePortionsRemaining} left to buy',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _confirmBuy(l),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    child: const Text('Buy & Donate'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}