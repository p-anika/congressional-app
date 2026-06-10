import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_listing.dart';
import '../../providers/food_listing_provider.dart';
import '../../theme.dart';
import '../../widgets/allergen_chips.dart';
import '../../widgets/food_listing_card.dart';

class RestaurantListingsScreen extends StatefulWidget {
  const RestaurantListingsScreen({super.key});

  @override
  State<RestaurantListingsScreen> createState() =>
      _RestaurantListingsScreenState();
}

class _RestaurantListingsScreenState extends State<RestaurantListingsScreen> {
  String? _restaurantId;
  List<FoodListing> _listings = [];
  StreamSubscription<QuerySnapshot>? _listingsSub;

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
  }

  @override
  void dispose() {
    _listingsSub?.cancel();
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
      body: _listings.isEmpty
          ? const Center(
              child: Text(
                'No active listings.\nTap + to add available food.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _listings.length,
              itemBuilder: (ctx, i) {
                final l = _listings[i];
                return FoodListingCard(
                  listing: l,
                  onEdit: () => _showEditSheet(context, l),
                  onDelete: () => _confirmDelete(context, l.id),
                );
              },
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

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove listing?'),
        content: const Text(
            'This will mark the listing as unavailable and remove it from the map.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context
                  .read<FoodListingProvider>()
                  .updateListing(id, {'isAvailable': false});
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
  final _containsCtrl = TextEditingController();
  List<String> _allergens = [];
  List<String> _contains = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _item.text = e.item;
      _amount.text = e.amount;
      _feedsPeople.text = e.feedsPeople.toString();
      _allergens = List.from(e.allergens);
      _contains = List.from(e.contains);
    }
  }

  @override
  void dispose() {
    _item.dispose();
    _amount.dispose();
    _feedsPeople.dispose();
    _containsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
        });
      } else {
        await provider.addListing(
          restaurantId: widget.restaurantId,
          item: _item.text.trim(),
          amount: _amount.text.trim(),
          feedsPeople: int.tryParse(_feedsPeople.text) ?? 0,
          allergens: _allergens,
          contains: _contains,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              decoration:
                  const InputDecoration(labelText: 'Amount (e.g. 20 portions)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedsPeople,
              decoration: const InputDecoration(labelText: 'Feeds how many people?'),
              keyboardType: TextInputType.number,
            ),
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
