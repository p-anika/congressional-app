import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_listing.dart';
import '../../models/portion_claim.dart';
import '../../providers/food_listing_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';
import '../../widgets/allergen_chips.dart';

class RestaurantListingsScreen extends StatefulWidget {
  const RestaurantListingsScreen({super.key});

  @override
  State<RestaurantListingsScreen> createState() =>
      _RestaurantListingsScreenState();
}

class _RestaurantListingsScreenState extends State<RestaurantListingsScreen> {
  String? _restaurantId;
  List<FoodListing> _listings = [];
  List<FoodListing> _completedListings = [];
  StreamSubscription<QuerySnapshot>? _listingsSub;
  StreamSubscription<List<FoodListing>>? _completedSub;

  @override
  void initState() {
    super.initState();
    _initListings();
  }

  Future<void> _initListings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .get();

    if (!mounted || snap.docs.isEmpty) return;

    final restaurantId = snap.docs.first.id;
    print('RestaurantListingsScreen: restaurantId=$restaurantId for uid=$uid');

    setState(() => _restaurantId = restaurantId);

    _listingsSub = FirebaseFirestore.instance
        .collection('foodListings')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() => _listings =
                snapshot.docs.map(FoodListing.fromFirestore).toList());
          }
        });

    _completedSub = FirebaseService.completedListingsByRestaurant(restaurantId)
        .listen((listings) {
      if (mounted) setState(() => _completedListings = listings);
    });
  }

  @override
  void dispose() {
    _listingsSub?.cancel();
    _completedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restaurantId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, _restaurantId!),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Active listings, split by type ──────────────────────────────
          Builder(builder: (_) {
            final freeListings = _listings.where((l) => !l.isPurchasable).toList();
            final purchaseListings = _listings.where((l) => l.isPurchasable).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Free Listings',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                ),
                if (freeListings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No free listings.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...freeListings.map((l) => _RestaurantListingCard(
                        listing: l,
                        onEdit: () => _showEditSheet(context, l),
                      )),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('For Purchase',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                ),
                if (purchaseListings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No listings for purchase.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...purchaseListings.map((l) => _RestaurantListingCard(
                        listing: l,
                        onEdit: () => _showEditSheet(context, l),
                      )),
              ],
            );
          }),

          // ── Completed orders ─────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text('Completed Orders',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
          ),
          if (_completedListings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No completed orders yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._completedListings.map((l) => _CompletedListingCard(listing: l)),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, String restaurantId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddFoodListingSheet(restaurantId: restaurantId),
    );
  }

  void _showEditSheet(BuildContext context, FoodListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddFoodListingSheet(
          restaurantId: listing.restaurantId, existing: listing),
    );
  }
}

class _AddFoodListingSheet extends StatefulWidget {
  final String restaurantId;
  final FoodListing? existing;

  const _AddFoodListingSheet({required this.restaurantId, this.existing});

  @override
  State<_AddFoodListingSheet> createState() => _AddFoodListingSheetState();
}

class _AddFoodListingSheetState extends State<_AddFoodListingSheet> {
  final _item = TextEditingController();
  final _amount = TextEditingController();
  final _feedsPeople = TextEditingController();
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _containsCtrl = TextEditingController();
  List<String> _allergens = [];
  List<String> _contains = [];
  bool _saving = false;
  bool _isPurchasable = false; // false = free listing

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _item.text = e.item;
      _amount.text = e.amount;
      _feedsPeople.text = e.feedsPeople.toString();
      _cost.text = e.cost?.toString() ?? '';
      _price.text = e.price?.toString() ?? '';
      _isPurchasable = e.isPurchasable;
      _allergens = List.from(e.allergens);
      _contains = List.from(e.contains);
    }
  }

  @override
  void dispose() {
    _item.dispose();
    _amount.dispose();
    _feedsPeople.dispose();
    _cost.dispose();
    _price.dispose();
    _containsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate price doesn't exceed market cost when purchasable
    final costValue = double.tryParse(_cost.text.trim());
    final priceValue = _isPurchasable ? double.tryParse(_price.text.trim()) : null;
    if (_isPurchasable) {
      if (priceValue == null) {
        _showError('Enter a valid price for this meal.');
        return;
      }
      if (costValue != null && priceValue > costValue) {
        _showError('Price cannot exceed the market cost per portion.');
        return;
      }
    }
    
    setState(() => _saving = true);
    final provider = context.read<FoodListingProvider>();
    try {
      if (widget.existing != null) {
        await provider.updateListing(widget.existing!.id, {
          'item': _item.text.trim(),
          'amount': _amount.text.trim(),
          'feedsPeople': int.tryParse(_feedsPeople.text) ?? 0,
          'allergens': _allergens,
          'contains': _contains,
          'cost': costValue,
          'price': priceValue,
        });
      } else {
        await FirebaseFirestore.instance.collection('foodListings').add({
          'restaurantId': widget.restaurantId,
          'item': _item.text.trim(),
          'amount': _amount.text.trim(),
          'feedsPeople': int.tryParse(_feedsPeople.text) ?? 0,
          'allergens': _allergens,
          'contains': _contains,
          'isAvailable': true,
          'createdAt': Timestamp.now(),
          'expiresAt': null,
          'cost': costValue,
          'price': priceValue,
          'sponsoredByVolunteerId': null,
          'sponsoredAt': null,
        });
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addContainsTag() {
    final tag = _containsCtrl.text.trim();
    if (tag.isNotEmpty && !_contains.contains(tag)) {
      setState(() {
        _contains.add(tag);
        _containsCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEdit ? 'Edit Listing' : 'Add Food Listing',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _item,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Description (e.g. "family-size trays")',
                helperText: 'Just a description — the portion count below is what matters for claiming.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedsPeople,
              decoration: const InputDecoration(
                labelText: 'Number of portions',
                helperText: 'This is what people actually claim or buy against.',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(
                  labelText: 'Market cost per portion (\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // ── NEW: Free / For Purchase toggle ──────────────────────────
            const Text('Listing Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Free')),
                ButtonSegment(value: true, label: Text('For Purchase')),
              ],
              selected: {_isPurchasable},
              onSelectionChanged: (v) => setState(() => _isPurchasable = v.first),
            ),
            if (_isPurchasable) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Price per portion (\$)',
                  helperText: 'A volunteer pays this amount to sponsor the meal.',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Allergens',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            AllergenSelector(
              selected: _allergens,
              onChanged: (v) => setState(() => _allergens = v),
            ),
            const SizedBox(height: 16),
            const Text('Contains (ingredients/tags)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _containsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Add tag', isDense: true),
                    onSubmitted: (_) => _addContainsTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  onPressed: _addContainsTag,
                ),
              ],
            ),
            if (_contains.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _contains
                    .map((c) => Chip(
                          label: Text(c),
                          onDeleted: () =>
                              setState(() => _contains.remove(c)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save Changes' : 'Add Listing'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantListingCard extends StatelessWidget {
  final FoodListing listing;
  final VoidCallback? onEdit;

  const _RestaurantListingCard({
    required this.listing,
    this.onEdit,
  });


  Future<void> _markPortionPickedUp(BuildContext context) async {
    try {
      await FirebaseService.completeOldestClaim(listing.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked one portion as picked up.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _recordWalkIn(BuildContext context) async {
    try {
      await FirebaseService.recordWalkInPickup(listing.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorded a walk-in pickup.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _endListing(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('End this listing'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'What happened to the remaining portions?',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'donatedInPerson'),
            child: const ListTile(
              leading: Icon(Icons.volunteer_activism, color: Colors.green),
              title: Text('Given away in person'),
              subtitle: Text('Counts toward your donation total'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'soldElsewhere'),
            child: const ListTile(
              leading: Icon(Icons.attach_money, color: AppColors.textSecondary),
              title: Text('Sold to a walk-in customer'),
              subtitle: Text('Not a donation — no credit'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'spoiled'),
            child: const ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Spoiled / discarded'),
              subtitle: Text('Not a donation — no credit'),
            ),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await FirebaseService.endListing(listing.id, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing ended.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = listing.availablePortions;

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
                  child: Text(listing.item,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            if (listing.amount.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(listing.amount.trim(),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 4),
            if (listing.isPurchasable) ...[
              Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '\$${listing.price!.toStringAsFixed(2)}/portion · ${listing.sponsoredCount} of ${listing.totalPortions} sponsored',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${listing.completedCount} of ${listing.totalPortions} portions picked up',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<PortionClaim>>(
              stream: FirebaseService.claimsByListing(listing.id),
              builder: (context, snap) {
                final pending = snap.data ?? [];
                final pendingCount = pending.fold<int>(0, (sum, c) => sum + c.quantity);
                if (pendingCount == 0) {
                  return const Text('No portions currently claimed through the app.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text('$pendingCount portion${pendingCount == 1 ? '' : 's'} awaiting pickup',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    TextButton.icon(
                      onPressed: () => _markPortionPickedUp(context),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Picked Up'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                );
              },
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
                          label: Text(c, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          backgroundColor: AppColors.background,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (remaining > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _recordWalkIn(context),
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Walk-in Took One', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => _endListing(context),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('End Listing', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedListingCard extends StatelessWidget {
  final FoodListing listing;

  const _CompletedListingCard({required this.listing});

  String _formatAmount(String amount) => amount.trim();

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.item,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatAmount(listing.amount)} · ${listing.feedsPeople} portions total',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (listing.cost != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cost: \$${listing.cost!.toStringAsFixed(2)} per portion',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  if (listing.completedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Completed ${_formatDate(listing.completedAt)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
