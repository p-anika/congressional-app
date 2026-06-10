import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../theme.dart';
import '../role_select_screen.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({super.key});

  @override
  State<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  bool _editing = false;
  bool _saving = false;

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _hours = TextEditingController();

  late RestaurantProvider _restaurantProvider;

  @override
  void initState() {
    super.initState();
    _restaurantProvider = context.read<RestaurantProvider>();
    // Pre-fill if restaurant is already loaded (e.g. app restart with session)
    _syncControllers(_restaurantProvider.myRestaurant);
    // Listen for the first load and any subsequent Firestore updates
    _restaurantProvider.addListener(_onRestaurantChanged);
  }

  @override
  void dispose() {
    _restaurantProvider.removeListener(_onRestaurantChanged);
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _onRestaurantChanged() {
    // Only overwrite the controllers when we're not mid-edit
    if (_editing || _saving) return;
    _syncControllers(_restaurantProvider.myRestaurant);
  }

  void _syncControllers(Restaurant? restaurant) {
    if (restaurant == null) return;
    _name.text = restaurant.name;
    _address.text = restaurant.address;
    _contact.text = restaurant.contactInfo;
    _hours.text = restaurant.hoursOfOperation;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<RestaurantProvider>().updateMyRestaurant({
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'contactInfo': _contact.text.trim(),
      'hoursOfOperation': _hours.text.trim(),
    });
    if (mounted) setState(() { _editing = false; _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final restaurant = context.watch<RestaurantProvider>().myRestaurant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Info'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                  (_) => false,
                );
              }
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: restaurant == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!restaurant.isVerified)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.pending_outlined,
                              color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pending verification — not yet visible to users.',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!restaurant.isVerified) const SizedBox(height: 20),
                  if (_editing) ...[
                    _field('Restaurant Name', _name, Icons.restaurant),
                    const SizedBox(height: 14),
                    _field('Address', _address, Icons.location_on_outlined),
                    const SizedBox(height: 14),
                    _field('Contact Info', _contact, Icons.phone_outlined),
                    const SizedBox(height: 14),
                    _field('Hours of Operation', _hours,
                        Icons.schedule_outlined),
                    const SizedBox(height: 24),
                    _saving
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _editing = false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _save,
                                  child: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                  ] else ...[
                    _infoRow(Icons.restaurant, 'Name', restaurant.name),
                    _infoRow(Icons.location_on_outlined, 'Address',
                        restaurant.address),
                    _infoRow(Icons.phone_outlined, 'Contact',
                        restaurant.contactInfo),
                    _infoRow(Icons.schedule_outlined, 'Hours',
                        restaurant.hoursOfOperation),
                    _infoRow(
                      restaurant.isVerified
                          ? Icons.verified_outlined
                          : Icons.pending_outlined,
                      'Status',
                      restaurant.isVerified
                          ? 'Verified'
                          : 'Pending verification',
                      valueColor: restaurant.isVerified
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(value.isEmpty ? '—' : value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
