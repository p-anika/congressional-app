import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  final Completer<GoogleMapController> _controller = Completer();
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 12,
  );
  Set<Marker> _markers = {};
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
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
      _initialCamera = CameraPosition(target: LatLng(lat, lng), zoom: 13);
      final ctrl = await _controller.future;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
    }
    setState(() => _locationLoaded = true);
    _buildMarkers();
  }

  void _buildMarkers() {
    final restaurants = context.read<RestaurantProvider>().verifiedRestaurants;
    final listings = context.read<FoodListingProvider>().allListings;
    final activeRestaurantIds =
        listings.map((l) => l.restaurantId).toSet();

    setState(() {
      _markers = restaurants
          .where((r) => activeRestaurantIds.contains(r.id))
          .map((r) => Marker(
                markerId: MarkerId(r.id),
                position: LatLng(r.lat, r.lng),
                infoWindow: InfoWindow(title: r.name, snippet: r.hoursOfOperation),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                onTap: () => _showRestaurantSheet(r),
              ))
          .toSet();
    });
  }

  void _showRestaurantSheet(Restaurant restaurant) {
    final listings = context
        .read<FoodListingProvider>()
        .listingsForRestaurant(restaurant.id);
    final userAllergies = context.read<UserProvider>().allergies;
    final userLat = context.read<UserProvider>().userLat;
    final userLng = context.read<UserProvider>().userLng;

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
    // Rebuild markers when providers update
    context.watch<RestaurantProvider>();
    context.watch<FoodListingProvider>();
    if (_locationLoaded) _buildMarkers();

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
      body: GoogleMap(
        initialCameraPosition: _initialCamera,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        onMapCreated: (ctrl) => _controller.complete(ctrl),
      ),
    );
  }
}
