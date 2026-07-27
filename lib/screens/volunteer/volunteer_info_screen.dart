import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../theme.dart';
import '../role_select_screen.dart';

class VolunteerInfoScreen extends StatefulWidget {
  const VolunteerInfoScreen({super.key});

  @override
  State<VolunteerInfoScreen> createState() => _VolunteerInfoScreenState();
}

class _VolunteerInfoScreenState extends State<VolunteerInfoScreen> {
  bool _editing = false;
  bool _saving = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _organization = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _organization.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<VolunteerProvider>().updateMyVolunteer({
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'organization': _organization.text.trim(),
    });
    if (mounted) setState(() { _editing = false; _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final volunteer = context.watch<VolunteerProvider>().myVolunteer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Info'),
        actions: [
          if (!_editing && volunteer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _name.text = volunteer.name;
                _phone.text = volunteer.phone;
                _organization.text = volunteer.organization;
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
      body: volunteer == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (volunteer.isApproved ? Colors.green : AppColors.warning)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: (volunteer.isApproved ? Colors.green : AppColors.warning)
                            .withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        volunteer.isApproved
                            ? Icons.verified_outlined
                            : Icons.pending_outlined,
                        color: volunteer.isApproved ? Colors.green : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          volunteer.isApproved
                              ? 'Your account is approved.'
                              : 'Pending review — some features are limited.',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_editing) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: volunteer.email),
                    decoration: const InputDecoration(
                      labelText: 'Email (cannot be changed)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _organization,
                    decoration: const InputDecoration(
                        labelText: 'Organization (optional)',
                        prefixIcon: Icon(Icons.groups_outlined)),
                  ),
                  const SizedBox(height: 20),
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _editing = false),
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
                  _infoRow(Icons.person_outline, 'Name', volunteer.name),
                  _infoRow(Icons.email_outlined, 'Email', volunteer.email),
                  _infoRow(Icons.phone_outlined, 'Phone',
                      volunteer.phone.isEmpty ? 'Not set' : volunteer.phone),
                  _infoRow(Icons.groups_outlined, 'Organization',
                      volunteer.organization.isEmpty
                          ? 'None'
                          : volunteer.organization),
                ],
              ],
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
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
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}