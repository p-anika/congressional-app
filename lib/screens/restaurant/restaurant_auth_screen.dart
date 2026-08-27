import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'restaurant_home_screen.dart';

class RestaurantAuthScreen extends StatefulWidget {
  const RestaurantAuthScreen({super.key});

  @override
  State<RestaurantAuthScreen> createState() => _RestaurantAuthScreenState();
}

class _RestaurantAuthScreenState extends State<RestaurantAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = false;
  bool _calculateTaxDeduction = true;
  String? _error;

  // Login fields
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // Signup fields
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();
  final _restaurantName = TextEditingController();
  final _address = TextEditingController();
  final _contactInfo = TextEditingController();
  final _hours = TextEditingController();
  final _lastYearRevenue = TextEditingController();
  final _projectedGrowth = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    _restaurantName.dispose();
    _address.dispose();
    _contactInfo.dispose();
    _hours.dispose();
    _lastYearRevenue.dispose();
    _projectedGrowth.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context
          .read<AuthProvider>()
          .signInRestaurant(_loginEmail.text.trim(), _loginPassword.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RestaurantHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final coords = await LocationService.geocodeAddress(_address.text.trim());
      if (coords == null) {
        if (mounted) {
          setState(() => _error =
              'Could not find address, please enter a valid address');
        }
        return;
      }
      await auth.signUpRestaurant(
        email: _signupEmail.text.trim(),
        password: _signupPassword.text,
        restaurantName: _restaurantName.text.trim(),
        address: _address.text.trim(),
        contactInfo: _contactInfo.text.trim(),
        hours: _hours.text.trim(),
        lat: coords['lat']!,
        lng: coords['lng']!,
        lastYearRevenue:
            double.tryParse(_lastYearRevenue.text.trim()) ?? 0.0,
        projectedGrowth:
            double.tryParse(_projectedGrowth.text.trim()) ?? 0.0,
        calculateTaxDeduction: _calculateTaxDeduction, // NEW
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RestaurantHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Portal'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Log In'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildLoginTab(),
          _buildSignupTab(),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Welcome back',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Sign in to manage your food listings',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          TextField(
            controller: _loginEmail,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPassword,
            decoration: const InputDecoration(
                labelText: 'Password', prefixIcon: Icon(Icons.lock_outlined)),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(onPressed: _login, child: const Text('Log In')),
        ],
      ),
    );
  }

  Widget _buildSignupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Register your restaurant',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('After signup, an admin will verify your restaurant.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          TextField(
            controller: _restaurantName,
            decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                prefixIcon: Icon(Icons.restaurant)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactInfo,
            decoration: const InputDecoration(
                labelText: 'Phone Number (e.g. 123-456-7890)',
                prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(
                labelText: 'Hours of Operation (e.g. Mon-Fri 9am-9pm)',
                prefixIcon: Icon(Icons.schedule_outlined)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastYearRevenue,
            decoration: const InputDecoration(
                labelText: "Last Year's Revenue (\$)",
                prefixIcon: Icon(Icons.attach_money)),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
                    const SizedBox(height: 16),
          TextField(
            controller: _projectedGrowth,
            decoration: const InputDecoration(
                labelText: 'Projected Revenue Growth This Year (%)',
                prefixIcon: Icon(Icons.trending_up)),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _calculateTaxDeduction,
            onChanged: (v) => setState(() => _calculateTaxDeduction = v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Calculate tax deduction eligibility'),
            subtitle: const Text(
              'Tracks donations against the 1% revenue floor for charitable '
              'tax deductions. Turn this off if you\'re a non-profit or '
              'don\'t need this tracking.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const Divider(height: 32),
          TextField(
            controller: _signupEmail,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _signupPassword,
            decoration: const InputDecoration(
                labelText: 'Password', prefixIcon: Icon(Icons.lock_outlined)),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _signup, child: const Text('Create Account')),
        ],
      ),
    );
  }
}
