import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant.dart';
import '../../providers/food_listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/food_listing_card.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final listings = context
        .watch<FoodListingProvider>()
        .listingsForRestaurant(restaurant.id);
    final userProvider = context.watch<UserProvider>();
    final userAllergies = userProvider.allergies;
    final userLat = userProvider.userLat;
    final userLng = userProvider.userLng;

    double? distance;
    if (userLat != null && userLng != null) {
      distance = LocationService.distanceInMiles(
          userLat, userLng, restaurant.lat, restaurant.lng);
    }

    final allergenConflictCount =
        listings.where((l) => l.hasAllergenConflict(userAllergies)).length;

    return Theme(
      data: buildUserTheme(),
      child: Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: ListView(
        children: [
          _InfoCard(
            restaurant: restaurant,
            distance: distance,
            allergenWarningCount: allergenConflictCount,
            userAllergyCount: userAllergies.length,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Available Food',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (listings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No active listings right now.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...listings.map((l) => FoodListingCard(
                  listing: l,
                  userAllergies: userAllergies,
                )),
          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final double? distance;
  final int allergenWarningCount;
  final int userAllergyCount;

  const _InfoCard({
    required this.restaurant,
    this.distance,
    required this.allergenWarningCount,
    required this.userAllergyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (distance != null)
              Row(
                children: [
                  Icon(Icons.directions_walk,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${distance!.toStringAsFixed(1)} mi away',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            _row(Icons.location_on_outlined, restaurant.address),
            const SizedBox(height: 6),
            _row(Icons.schedule_outlined, restaurant.hoursOfOperation),
            const SizedBox(height: 6),
            _row(Icons.phone_outlined, restaurant.contactInfo),
            if (userAllergyCount > 0 && allergenWarningCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$allergenWarningCount listing(s) contain allergens '
                        'matching your restrictions.',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.isEmpty ? '—' : text,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
