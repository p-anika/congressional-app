import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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

  void _showRestaurantSheet(Restaurant restaurant) {
    final listings = context
        .read<FoodListingProvider>()
        .listingsForRestaurant(restaurant.id);
    final userProvider = context.read<UserProvider>();
    final userAllergies = userProvider.allergies;
    final userLat = userProvider.userLat;
    final userLng = userProvider.userLng;

    double? distance;
    if (userLat != null && userLng != null) {
      distance = LocationService.distanceInMiles(
          userLat, userLng, restaurant.lat, restaurant.lng);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
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
            Text(restaurant.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(restaurant.hoursOfOperation,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (distance != null)
              Text('${distance.toStringAsFixed(1)} mi away',
                  style: const TextStyle(color: AppColors.primary)),
            const Divider(height: 24),
            const Text('Available Food',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            if (listings.isEmpty)
              const Text('No active listings.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...listings.map((l) => FoodListingCard(
                    listing: l,
                    userAllergies: userAllergies,
                  )),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RestaurantDetailScreen(restaurant: restaurant),
                  ),
                );
              },
              child: const Text('View Full Details'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurants =
        context.watch<RestaurantProvider>().verifiedRestaurants;
    final allListings = context.watch<FoodListingProvider>().allListings;
    final activeIds = allListings.map((l) => l.restaurantId).toSet();

    final markers = restaurants
        .where((r) =>
            activeIds.contains(r.id) && (r.lat != 0.0 || r.lng != 0.0))
        .map((r) => Marker(
              point: LatLng(r.lat, r.lng),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _showRestaurantSheet(r),
                child: const Icon(
                  Icons.location_pin,
                  color: AppColors.primary,
                  size: 44,
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
                    color: AppColors.primary.withValues(alpha: 0.6),
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
