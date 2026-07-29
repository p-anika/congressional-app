import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/portion_claim.dart';
import '../../models/food_listing.dart';
import '../../models/restaurant.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';

class MyClaimsScreen extends StatelessWidget {
  const MyClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Claims')),
      body: StreamBuilder<List<PortionClaim>>(
        stream: FirebaseService.claimsByUser(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final claims = List<PortionClaim>.from(snap.data!)
            ..sort((a, b) => b.claimedAt.compareTo(a.claimedAt));

          if (claims.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No claims yet. Claim a free portion or buy one from a listing to see it here.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final free = claims.where((c) => !c.paidBySelf).toList();
          final bought = claims.where((c) => c.paidBySelf).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Free portions are first come, first served. Restaurants may also '
                  'give portions to people who walk in without using the app, so a '
                  'free portion shown as available may occasionally run out before '
                  'you arrive.',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Free Claims',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (free.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No free claims yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...free.map((c) => _ClaimCard(claim: c)),
              const SizedBox(height: 20),
              const Text('Bought Portions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (bought.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No purchases yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...bought.map((c) => _ClaimCard(claim: c)),
            ],
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final PortionClaim claim;
  const _ClaimCard({required this.claim});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FoodListing?>(
      future: FirebaseService.getListingOnce(claim.listingId),
      builder: (context, listingSnap) {
        final listing = listingSnap.data;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              claim.status == 'completed' ? Icons.check_circle : Icons.schedule,
              color: claim.status == 'completed' ? Colors.green : AppColors.warning,
            ),
            title: Text(listing?.item ?? 'Listing no longer available'),
            subtitle: FutureBuilder<Restaurant?>(
              future: listing != null
                  ? FirebaseService.getRestaurantOnce(listing.restaurantId)
                  : Future.value(null),
              builder: (context, rSnap) {
                final restaurantName = rSnap.data?.name ?? '';
                return Text(
                  '${claim.quantity} portion${claim.quantity == 1 ? '' : 's'}'
                  '${restaurantName.isNotEmpty ? ' · $restaurantName' : ''}\n'
                  '${claim.status == 'completed' ? 'Picked up' : 'Awaiting pickup'}',
                );
              },
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}