import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_listing.dart';
import '../providers/auth_provider.dart';
import '../providers/food_listing_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/user_provider.dart';
import '../theme.dart';
import 'allergen_chips.dart';
import 'quantity_dialog.dart';

class FoodListingCard extends StatelessWidget {
  final FoodListing listing;
  final List<String> userAllergies;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FoodListingCard({
    super.key,
    required this.listing,
    this.userAllergies = const [],
    this.onEdit,
    this.onDelete,
  });

  String _displayAmount(String amount) => amount.trim();

  Future<void> _claim(BuildContext context, int max) async {
    final qty = await showQuantityDialog(context,
        title: 'How many portions?', max: max);
    if (qty == null) return;
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    try {
      await context.read<FoodListingProvider>().claimPortions(listing, uid, qty);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Claimed $qty portion${qty == 1 ? '' : 's'} — '
            'pending restaurant confirmation.',
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _requestDelivery(BuildContext context, int max) async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.userLat == null || userProvider.userLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Set your location on the My Info tab first so a volunteer can find you.'),
      ));
      return;
    }
    final qty = await showQuantityDialog(context,
        title: 'How many portions should be delivered?', max: max);
    if (qty == null) return;
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Delivery'),
        content: Text(
          'A volunteer will pick up $qty portion${qty == 1 ? '' : 's'} of '
          '"${listing.item}" and bring it to your saved location. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Request')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<DeliveryProvider>().requestDelivery(
            listing: listing,
            userId: uid,
            quantity: qty,
            userLat: userProvider.userLat!,
            userLng: userProvider.userLng!,
            userPhone: userProvider.user?.phone,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Delivery requested for $qty portion${qty == 1 ? '' : 's'}. A volunteer will be notified.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasConflict = listing.hasAllergenConflict(userAllergies);
    final isHomelessView = onEdit == null && onDelete == null;
    final available = listing.availablePortions;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    listing.item,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (hasConflict)
                  const Tooltip(
                    message: 'Contains allergens matching your restrictions',
                    child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  ),
                if (onEdit != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    color: AppColors.textSecondary,
                  ),
                ],
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    color: Colors.red.shade400,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _displayAmount(listing.amount).isEmpty
                      ? '—'
                      : _displayAmount(listing.amount),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$available portion${available == 1 ? '' : 's'} available',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            if (listing.isLastPortion && available > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.priority_high, size: 14, color: Colors.red),
                    SizedBox(width: 4),
                    Text('Last portion!',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
            ],
            if (listing.allergens.isNotEmpty) ...[
              const SizedBox(height: 8),
              AllergenChips(allergens: listing.allergens, small: true),
            ],
            if (listing.contains.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: listing.contains
                    .map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          backgroundColor: AppColors.background,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (isHomelessView && listing.isAvailable && available > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _claim(context, available),
                  child: const Text('I\'m Coming For This'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _requestDelivery(context, available),
                  icon: const Icon(Icons.delivery_dining_outlined, size: 16),
                  label: const Text('Too Far? Request Delivery'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
