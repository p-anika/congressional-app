import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_listing.dart';
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
          // ── Active listings ──────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Active Listings',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
          ),
          if (_listings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'No active listings.\nTap + to add available food.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ..._listings.map((l) => _RestaurantListingCard(
                  listing: l,
                  onEdit: () => _showEditSheet(context, l),
                  onDelete: () => _confirmDelete(context, l.id),
                  onComplete: () => _confirmComplete(context, l.id),
                )),

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

  void _confirmComplete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as completed?'),
        content: const Text('Mark this listing as completed/eaten? It will be removed from the active listings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('foodListings').doc(id).update({
                'isCompleted': true,
                'completedAt': Timestamp.now(),
                'isAvailable': false,
              });
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
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
  final _cost = TextEditingController();
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
      _cost.text = e.cost?.toString() ?? '';
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
    _containsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<FoodListingProvider>();
    try {
      final costValue = double.tryParse(_cost.text.trim());
      if (widget.existing != null) {
        await provider.updateListing(widget.existing!.id, {
          'item': _item.text.trim(),
          'amount': _amount.text.trim(),
          'feedsPeople': int.tryParse(_feedsPeople.text) ?? 0,
          'allergens': _allergens,
          'contains': _contains,
          'cost': costValue,
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
        });
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
                  const InputDecoration(labelText: 'Amount of Portions'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedsPeople,
              decoration: const InputDecoration(labelText: 'Feeds how many people?'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(labelText: 'Cost per portion (\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

class _RestaurantListingCard extends StatelessWidget {
  final FoodListing listing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onComplete;

  const _RestaurantListingCard({
    required this.listing,
    this.onEdit,
    this.onDelete,
    this.onComplete,
  });

  String _formatAmount(String amount) {
    final trimmed = amount.trim();
    return double.tryParse(trimmed) != null ? '$trimmed portions' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
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
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (onComplete != null)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    onPressed: onComplete,
                    visualDensity: VisualDensity.compact,
                    color: Colors.green,
                    tooltip: 'Mark as completed',
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatAmount(listing.amount),
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
                if (listing.cost != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.attach_money,
                      size: 14, color: AppColors.textSecondary),
                  Text(
                    listing.cost!.toStringAsFixed(2),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
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
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
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

class _CompletedListingCard extends StatelessWidget {
  final FoodListing listing;

  const _CompletedListingCard({required this.listing});

  String _formatAmount(String amount) {
    final trimmed = amount.trim();
    return double.tryParse(trimmed) != null ? '$trimmed portions' : trimmed;
  }

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
                    '${_formatAmount(listing.amount)} · Feeds ${listing.feedsPeople}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
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
