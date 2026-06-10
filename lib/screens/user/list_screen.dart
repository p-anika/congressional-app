import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant.dart';
import '../../providers/food_listing_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'restaurant_detail_screen.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurants = context.watch<RestaurantProvider>().verifiedRestaurants;
    final allListings = context.watch<FoodListingProvider>().allListings;
    final userProvider = context.watch<UserProvider>();
    final userLat = userProvider.userLat;
    final userLng = userProvider.userLng;
    final userAllergies = userProvider.allergies;

    // Keep only restaurants that have active listings
    final activeRestaurantIds = allListings.map((l) => l.restaurantId).toSet();
    var filtered =
        restaurants.where((r) => activeRestaurantIds.contains(r.id)).toList();

    // Sort: distance asc, then closing time (simple string sort as fallback)
    if (userLat != null && userLng != null) {
      filtered.sort((a, b) {
        final da = LocationService.distanceInMiles(
            userLat, userLng, a.lat, a.lng);
        final db = LocationService.distanceInMiles(
            userLat, userLng, b.lat, b.lng);
        return da.compareTo(db);
      });
    } else {
      filtered.sort((a, b) =>
          a.hoursOfOperation.compareTo(b.hoursOfOperation));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Available Food')),
      body: filtered.isEmpty
          ? const Center(
              child: Text(
                'No restaurants with active listings nearby.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final r = filtered[i];
                return _RestaurantCard(
                  restaurant: r,
                  itemCount: allListings
                      .where((l) => l.restaurantId == r.id)
                      .length,
                  distance: userLat != null && userLng != null
                      ? LocationService.distanceInMiles(
                          userLat, userLng, r.lat, r.lng)
                      : null,
                  hasAllergenWarning: userAllergies.isNotEmpty &&
                      allListings
                          .where((l) => l.restaurantId == r.id)
                          .any((l) => l.hasAllergenConflict(userAllergies)),
                );
              },
            ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final int itemCount;
  final double? distance;
  final bool hasAllergenWarning;

  const _RestaurantCard({
    required this.restaurant,
    required this.itemCount,
    this.distance,
    required this.hasAllergenWarning,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restaurant.hoursOfOperation,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.fastfood_outlined,
                            size: 13, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount item${itemCount == 1 ? '' : 's'} available',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary, fontSize: 12),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.near_me,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            '${distance!.toStringAsFixed(1)} mi',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (hasAllergenWarning)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'Some listings contain your allergens',
                    child: Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                  ),
                ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
