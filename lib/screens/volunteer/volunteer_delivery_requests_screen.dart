import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

class VolunteerDeliveryRequestsScreen extends StatefulWidget {
  const VolunteerDeliveryRequestsScreen({super.key});

  @override
  State<VolunteerDeliveryRequestsScreen> createState() =>
      _VolunteerDeliveryRequestsScreenState();
}

class _VolunteerDeliveryRequestsScreenState
    extends State<VolunteerDeliveryRequestsScreen> {
  double? _myLat;
  double? _myLng;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _myLat = pos?.latitude;
      _myLng = pos?.longitude;
      _locating = false;
    });
  }

  _TripEstimate _estimate(DeliveryRequest r) {
    final toPickup = (_myLat != null && _myLng != null)
        ? LocationService.distanceInMiles(
            _myLat!, _myLng!, r.pickupLat, r.pickupLng)
        : 0.0;
    final toDropoff = LocationService.distanceInMiles(
        r.pickupLat, r.pickupLng, r.dropoffLat, r.dropoffLng);
    return _TripEstimate(toPickup, toDropoff);
  }

  Future<void> _accept(DeliveryRequest r) async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    try {
      await context.read<DeliveryProvider>().acceptDelivery(r.id, uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You\'ve accepted delivery of "${r.item}". Head to ${r.restaurantName} to pick it up.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _complete(DeliveryRequest r) async {
    try {
      await context.read<DeliveryProvider>().completeDelivery(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery marked complete. Thank you!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openDirections(DeliveryRequest r) async {
    // origin -> restaurant (pickup) -> recipient (drop-off)
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (_myLat != null && _myLng != null) 'origin': '$_myLat,$_myLng',
      'destination': '${r.dropoffLat},${r.dropoffLng}',
      'waypoints': '${r.pickupLat},${r.pickupLng}',
      'travelmode': 'driving',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps for directions.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final deliveryProvider = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _loadLocation,
            tooltip: 'Update my location',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_locating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_myLat == null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Enable location to see accurate trip time estimates.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),

          if (uid != null)
            StreamBuilder<List<DeliveryRequest>>(
              stream: deliveryProvider.myAcceptedDeliveries(uid),
              builder: (context, snap) {
                final myDeliveries = snap.data ?? [];
                if (myDeliveries.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Active Deliveries',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...myDeliveries.map((r) => _DeliveryCard(
                          request: r,
                          estimate: _estimate(r),
                          isMine: true,
                          onComplete: () => _complete(r),
                          onDirections: () => _openDirections(r),
                        )),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

          const Text('Open Delivery Requests',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<DeliveryRequest>>(
            stream: deliveryProvider.pendingDeliveryRequests(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snap.data!;
              if (requests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No delivery requests right now.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return Column(
                children: requests
                    .map((r) => _DeliveryCard(
                          request: r,
                          estimate: _estimate(r),
                          isMine: false,
                          onAccept: () => _accept(r),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rough trip estimate: ~20 mph average city driving, plus a few minutes
/// buffer for the actual pickup handoff at the restaurant. It's a guide
/// for volunteers, not a routed/live ETA.
class _TripEstimate {
  final double volunteerToPickupMiles;
  final double pickupToDropoffMiles;
  _TripEstimate(this.volunteerToPickupMiles, this.pickupToDropoffMiles);

  double get totalMiles => volunteerToPickupMiles + pickupToDropoffMiles;
  int get totalMinutes => ((totalMiles / 20) * 60).round() + 5;
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryRequest request;
  final _TripEstimate estimate;
  final bool isMine;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onDirections;

  const _DeliveryCard({
    required this.request,
    required this.estimate,
    required this.isMine,
    this.onAccept,
    this.onComplete,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${request.quantity} × ${request.item}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (isMine)
                  const Chip(
                    label:
                        Text('Accepted', style: TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _locationRow(Icons.storefront_outlined, 'Pickup',
                request.restaurantName, request.pickupAddress, AppColors.primary),
            const SizedBox(height: 6),
            _locationRow(
                Icons.home_outlined,
                'Drop-off',
                'Recipient location',
                '${request.dropoffLat.toStringAsFixed(3)}, ${request.dropoffLng.toStringAsFixed(3)}',
                AppColors.volunteerPrimary),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Est. total trip: ~${estimate.totalMinutes} min '
                      '(${estimate.totalMiles.toStringAsFixed(1)} mi)',
                      style:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (onAccept != null)
                  Expanded(
                    child: ElevatedButton(
                        onPressed: onAccept, child: const Text('Accept Delivery')),
                  ),
                if (onDirections != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Directions'),
                    ),
                  ),
                if (onComplete != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: onComplete, child: const Text('Mark Delivered')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(
      IconData icon, String label, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label · $title',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}