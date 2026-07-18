import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/food_listing.dart';
import '../../models/restaurant.dart';
import '../../providers/food_listing_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/food_listing_card.dart';
import 'restaurant_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  static final _defaultCenter = LatLng(37.7749, -122.4194);
  late LatLng _center;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _center = _defaultCenter;
    _initLocation();
  }

  Future<void> _initLocation() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.userLat == null) {
      await userProvider.refreshLocation();
    }
    if (!mounted) return;
    final lat = userProvider.userLat;
    final lng = userProvider.userLng;
    if (lat != null && lng != null) {
      _center = LatLng(lat, lng);
      _mapController.move(_center, 13);
    }
    setState(() => _locationLoaded = true);
  }

  void _showRestaurantSheet(List<Restaurant> restaurants, int initialIndex) {
    final allListings = context.read<FoodListingProvider>().allListings;
    final userProvider = context.read<UserProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RestaurantSheet(
        restaurants: restaurants,
        initialIndex: initialIndex,
        allListings: allListings,
        userAllergies: userProvider.allergies,
        userLat: userProvider.userLat,
        userLng: userProvider.userLng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurants =
        context.watch<RestaurantProvider>().verifiedRestaurants;
    final allListings = context.watch<FoodListingProvider>().allListings;
    final activeIds = allListings.map((l) => l.restaurantId).toSet();

    print('MapScreen: ${restaurants.length} verified restaurants, '
        '${activeIds.length} with active listings');
    for (final r in restaurants) {
      print('  restaurant id=${r.id} name=${r.name} '
          'lat=${r.lat} lng=${r.lng} '
          'hasListings=${activeIds.contains(r.id)}');
    }

    final activeRestaurants = restaurants
        .where((r) =>
            activeIds.contains(r.id) && (r.lat != 0.0 || r.lng != 0.0))
        .toList();

    final markers = activeRestaurants
        .asMap()
        .entries
        .map((entry) => Marker(
              point: LatLng(entry.value.lat, entry.value.lng),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showRestaurantSheet(activeRestaurants, entry.key),
                child: Icon(
                  Icons.location_pin,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Near You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initLocation,
            tooltip: 'Re-center',
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.congressional_app.app',
          ),
          if (_locationLoaded)
            CircleLayer(
              circles: [
                if (context.read<UserProvider>().userLat != null)
                  CircleMarker(
                    point: LatLng(
                      context.read<UserProvider>().userLat!,
                      context.read<UserProvider>().userLng!,
                    ),
                    radius: 8,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: false,
                  ),
              ],
            ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _RestaurantSheet extends StatefulWidget {
  final List<Restaurant> restaurants;
  final int initialIndex;
  final List<FoodListing> allListings;
  final List<String> userAllergies;
  final double? userLat;
  final double? userLng;

  const _RestaurantSheet({
    required this.restaurants,
    required this.initialIndex,
    required this.allListings,
    required this.userAllergies,
    this.userLat,
    this.userLng,
  });

  @override
  State<_RestaurantSheet> createState() => _RestaurantSheetState();
}

class _RestaurantSheetState extends State<_RestaurantSheet> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurants[_index];
    final total = widget.restaurants.length;
    final listings = widget.allListings
        .where((l) => l.restaurantId == restaurant.id)
        .toList();
    double? distance;
    if (widget.userLat != null && widget.userLng != null) {
      distance = LocationService.distanceInMiles(
          widget.userLat!, widget.userLng!, restaurant.lat, restaurant.lng);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (total > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restaurant ${_index + 1} of $total',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _index < total - 1
                          ? () => setState(() => _index++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          Text(restaurant.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(restaurant.hoursOfOperation,
              style: const TextStyle(color: AppColors.textSecondary)),
          if (distance != null)
            Text('${distance.toStringAsFixed(1)} mi away',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary)),
          const Divider(height: 24),
          const Text('Available Food',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          if (listings.isEmpty)
            const Text('No active listings.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            ...listings.map((l) => FoodListingCard(
                  listing: l,
                  userAllergies: widget.userAllergies,
                )),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      RestaurantDetailScreen(restaurant: restaurant),
                ),
              );
            },
            child: const Text('View Full Details'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Showing directions to restaurant')),
              );
            },
            child: const Text('Show Directions'),
          ),
        ],
      ),
    );
  }
}
