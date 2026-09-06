import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/location_service.dart';
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
  bool _calculateTaxDeduction = true;
  String? _error;

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();
  final _lastYearRevenue = TextEditingController();
  final _projectedGrowth = TextEditingController();

  final _businessLicense = TextEditingController();
  final _stateRegistration = TextEditingController();
  final _foodHandlerPermit = TextEditingController();
  final _einOrTaxId = TextEditingController();

  late RestaurantProvider _restaurantProvider;

  @override
  void initState() {
    super.initState();
    _restaurantProvider = context.read<RestaurantProvider>();
    // Pre-fill if restaurant is already loaded (e.g. app restart with session)
    _syncControllers(_restaurantProvider.myRestaurant);
    print('initState phone: ${_phone.text}');
    // Listen for the first load and any subsequent Firestore updates
    _restaurantProvider.addListener(_onRestaurantChanged);
  }

  @override
  void dispose() {
    _restaurantProvider.removeListener(_onRestaurantChanged);
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _hours.dispose();
    _lastYearRevenue.dispose();
    _projectedGrowth.dispose();
    _businessLicense.dispose();
    _stateRegistration.dispose();
    _foodHandlerPermit.dispose();
    _einOrTaxId.dispose();
    super.dispose();
  }

  void _onRestaurantChanged() {
    // Only overwrite the controllers when we're not mid-edit
    if (_editing || _saving) return;
    _syncControllers(_restaurantProvider.myRestaurant);
  }

  void _syncControllers(Restaurant? restaurant) {
    if (restaurant == null) return;
    if (!mounted) return;
    print('_syncControllers called: contactInfo=${restaurant.contactInfo}');
    _name.text = restaurant.name;
    _address.text = restaurant.address;
    _phone.text = restaurant.contactInfo;
    print('phone after set: ${_phone.text}');
    _hours.text = restaurant.hoursOfOperation;
    _lastYearRevenue.text = restaurant.lastYearRevenue?.toString() ?? '';
    _projectedGrowth.text = restaurant.projectedGrowth?.toString() ?? '';
    _calculateTaxDeduction = restaurant.calculateTaxDeduction;
    _businessLicense.text = restaurant.businessLicenseNumber ?? '';
    _stateRegistration.text = restaurant.stateRegistrationNumber ?? '';
    _foodHandlerPermit.text = restaurant.foodHandlerPermitNumber ?? '';
    _einOrTaxId.text = restaurant.einOrTaxId ?? '';
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final provider = context.read<RestaurantProvider>();
    final coords = await LocationService.geocodeAddress(_address.text.trim());
    if (coords == null) {
      if (mounted) {
        setState(() {
          _error = 'Could not find address, please enter a valid address';
          _saving = false;
        });
      }
      return;
    }
    await provider.updateMyRestaurant({
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'contactInfo': _phone.text.trim(),
      'hoursOfOperation': _hours.text.trim(),
      'lat': coords['lat'],
      'lng': coords['lng'],
      'lastYearRevenue': double.tryParse(_lastYearRevenue.text.trim()),
      'projectedGrowth': double.tryParse(_projectedGrowth.text.trim()),
      'calculateTaxDeduction': _calculateTaxDeduction,
      'businessLicenseNumber': _businessLicense.text.trim(),
      'stateRegistrationNumber': _stateRegistration.text.trim(),
      'foodHandlerPermitNumber': _foodHandlerPermit.text.trim(),
      'einOrTaxId': _einOrTaxId.text.trim(),
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
              onPressed: () {
                final r = _restaurantProvider.myRestaurant;
                if (r != null) _syncControllers(r);
                setState(() => _editing = true);
              },
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
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(
                          text: FirebaseAuth.instance.currentUser?.email ?? ''),
                      decoration: const InputDecoration(
                        labelText: 'Email (cannot be changed)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    _field('Phone Number', _phone, Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _field('Hours of Operation', _hours,
                        Icons.schedule_outlined),
                    const SizedBox(height: 14),
                    _field("Last Year's Revenue (\$)", _lastYearRevenue,
                        Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 14),
                    _field('Projected Revenue Growth This Year (%)',
                        _projectedGrowth, Icons.trending_up,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _calculateTaxDeduction,
                      onChanged: (v) =>
                          setState(() => _calculateTaxDeduction = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Calculate tax deduction eligibility'),
                      subtitle: const Text(
                        'Turn off if you don\'t need 1%-floor tracking.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 32),
                    const Text('Licensing & Tax Info',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                      'Optional, but recommended for donation recordkeeping.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    _field('Business License Number', _businessLicense,
                        Icons.badge_outlined),
                    const SizedBox(height: 14),
                    _field('State Registration Number', _stateRegistration,
                        Icons.assignment_outlined),
                    const SizedBox(height: 14),
                    _field('Food Handler Permit Number', _foodHandlerPermit,
                        Icons.verified_user_outlined),
                    const SizedBox(height: 14),
                    _field('EIN / Tax ID', _einOrTaxId,
                        Icons.numbers_outlined),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
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
                    _infoRow(Icons.phone_outlined, 'Phone',
                        restaurant.contactInfo),
                    _infoRow(Icons.email_outlined, 'Email',
                        FirebaseAuth.instance.currentUser?.email ?? ''),
                    _infoRow(Icons.schedule_outlined, 'Hours',
                        restaurant.hoursOfOperation),
                    _infoRow(Icons.attach_money, 'Last Year\'s Revenue',
                        restaurant.lastYearRevenue != null
                            ? '\$${restaurant.lastYearRevenue!.toStringAsFixed(2)}'
                            : '—'),
                    _infoRow(Icons.trending_up, 'Projected Growth',
                        restaurant.projectedGrowth != null
                            ? '${restaurant.projectedGrowth!.toStringAsFixed(1)}%'
                            : '—'),
                    _infoRow(
                      restaurant.calculateTaxDeduction
                          ? Icons.receipt_long
                          : Icons.receipt_long_outlined,
                      'Tax Deduction Tracking',
                      restaurant.calculateTaxDeduction ? 'Enabled' : 'Disabled',
                    ),
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
                    const Divider(height: 32),
                    const Text('Licensing & Tax Info',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    _infoRow(Icons.badge_outlined, 'Business License',
                        restaurant.businessLicenseNumber ?? ''),
                    _infoRow(Icons.assignment_outlined, 'State Registration',
                        restaurant.stateRegistrationNumber ?? ''),
                    _infoRow(Icons.verified_user_outlined, 'Food Handler Permit',
                        restaurant.foodHandlerPermitNumber ?? ''),
                    _infoRow(Icons.numbers_outlined, 'EIN / Tax ID',
                        restaurant.einOrTaxId ?? ''),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
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
