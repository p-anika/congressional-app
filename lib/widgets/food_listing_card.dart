import 'package:flutter/material.dart';
import '../models/food_listing.dart';
import '../theme.dart';
import 'allergen_chips.dart';

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

  String _displayAmount(String amount) =>
      double.tryParse(amount) != null ? '$amount portions' : amount;

  @override
  Widget build(BuildContext context) {
    final hasConflict = listing.hasAllergenConflict(userAllergies);

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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (hasConflict)
                  const Tooltip(
                    message: 'Contains allergens matching your restrictions',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
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
            // ── NEW: price / sponsorship badge for purchasable listings ──
            if (listing.isPurchasable) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (listing.isSponsored ? Colors.green : AppColors.allergenChip)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      listing.isSponsored
                          ? Icons.volunteer_activism
                          : Icons.attach_money,
                      size: 14,
                      color: listing.isSponsored ? Colors.green : AppColors.allergenChip,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.isSponsored
                          ? 'Free — sponsored by a volunteer'
                          : 'Buy for \$${listing.price!.toStringAsFixed(2)}/portion',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: listing.isSponsored
                            ? Colors.green.shade800
                            : AppColors.allergenChip,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _displayAmount(listing.amount),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.people_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Feeds ${listing.feedsPeople}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
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
                          label: Text(c,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                          backgroundColor: AppColors.background,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
