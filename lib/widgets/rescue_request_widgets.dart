import 'package:flutter/material.dart';
import '../models/rescue_request.dart';
import '../services/location_service.dart';
import '../services/rescue_service.dart';
import '../theme.dart';

// Small building blocks for the rescueRequests delivery flow, dropped into
// the existing recipient / volunteer / restaurant screens.

// ── Shared helpers ──────────────────────────────────────────────────────────

Future<void> runRescueAction(BuildContext context,
    Future<void> Function() action, String success) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }
}

Future<bool> confirmRescueStep(
    BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes')),
      ],
    ),
  );
  return ok == true;
}

/// Opens Google Maps, or lets the user pick Apple Maps on iOS/macOS.
/// Uses lat/lng when available, otherwise the address text.
Future<void> openRescueDirections(BuildContext context,
    {double? lat, double? lng, required String address}) async {
  var useApple = false;
  if (RescueService.canUseAppleMaps) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Open directions in'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'apple'),
            child: const Text('Apple Maps'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'google'),
            child: const Text('Google Maps'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    useApple = choice == 'apple';
  }
  final launched = await RescueService.launchDirections(
      lat: lat, lng: lng, address: address, apple: useApple);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for directions.')),
    );
  }
}

// ── Status chip ─────────────────────────────────────────────────────────────

class RescueStatusChip extends StatelessWidget {
  final String status;
  final bool forRecipient;
  const RescueStatusChip(
      {super.key, required this.status, this.forRecipient = false});

  static String label(String status, {bool forRecipient = false}) {
    switch (status) {
      case RescueStatus.open:
        return forRecipient ? 'Waiting for a volunteer' : 'Open';
      case RescueStatus.claimed:
        return forRecipient ? 'Volunteer on the way' : 'Accepted';
      case RescueStatus.pickupPendingRestaurant:
        return forRecipient ? 'At the restaurant' : 'Awaiting restaurant';
      case RescueStatus.pickedUp:
        return forRecipient ? 'On the way to you' : 'Picked up';
      case RescueStatus.deliveredPendingRecipient:
        return forRecipient ? 'Delivered — please confirm' : 'Awaiting recipient';
      case RescueStatus.completed:
        return forRecipient ? 'Received' : 'Completed';
      case RescueStatus.disputed:
        return forRecipient ? 'Reported not received' : 'Disputed';
      case RescueStatus.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case RescueStatus.completed:
      case RescueStatus.pickedUp:
        return Colors.green;
      case RescueStatus.cancelled:
      case RescueStatus.disputed:
        return Colors.red;
      case RescueStatus.pickupPendingRestaurant:
      case RescueStatus.deliveredPendingRecipient:
        return AppColors.warning;
      case RescueStatus.claimed:
        return AppColors.volunteerPrimary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label(status, forRecipient: forRecipient),
          style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color(status),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Recipient: delivery location popup ──────────────────────────────────────

/// Popup shown from the existing "Request Delivery" button. Asks for a
/// delivery address (or current location) and optional notes, then calls
/// [onSubmit]. Returns true if the request was created.
Future<bool> showRescueDeliveryPopup(
  BuildContext context, {
  required String itemName,
  required int quantity,
  required Future<void> Function(RescueDropoff dropoff) onSubmit,
}) async {
  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RescueDeliveryLocationDialog(
      itemName: itemName,
      quantity: quantity,
      onSubmit: onSubmit,
    ),
  );
  return created == true;
}

class RescueDeliveryLocationDialog extends StatefulWidget {
  final String itemName;
  final int quantity;
  final Future<void> Function(RescueDropoff dropoff) onSubmit;
  const RescueDeliveryLocationDialog({
    super.key,
    required this.itemName,
    required this.quantity,
    required this.onSubmit,
  });

  @override
  State<RescueDeliveryLocationDialog> createState() =>
      _RescueDeliveryLocationDialogState();
}

class _RescueDeliveryLocationDialogState
    extends State<RescueDeliveryLocationDialog> {
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  double? _currentLat;
  double? _currentLng;
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  bool get _usingCurrent => _currentLat != null;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos == null) {
        _error = 'Couldn\'t get your location. Turn on location or type an address.';
      } else {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      }
    });
  }

  Future<void> _submit() async {
    final notes = _notesCtrl.text.trim();
    final typed = _addressCtrl.text.trim();
    if (!_usingCurrent && typed.isEmpty) {
      setState(() =>
          _error = 'Enter a delivery address or use your current location.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      RescueDropoff dropoff;
      if (_usingCurrent) {
        dropoff = RescueDropoff(
          address: 'Current location '
              '(${_currentLat!.toStringAsFixed(5)}, ${_currentLng!.toStringAsFixed(5)})',
          lat: _currentLat!,
          lng: _currentLng!,
          notes: notes,
        );
      } else {
        // Geocoding is optional: if it fails, save the address text alone.
        final coords = await RescueService.tryGeocode(typed);
        dropoff = RescueDropoff(
            address: typed, lat: coords?.lat, lng: coords?.lng, notes: notes);
      }
      await widget.onSubmit(dropoff);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Where should we deliver?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A volunteer will bring ${widget.quantity} portion'
              '${widget.quantity == 1 ? '' : 's'} of "${widget.itemName}".',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_usingCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Using your current location')),
                    IconButton(
                      tooltip: 'Type an address instead',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _currentLat = null;
                        _currentLng = null;
                      }),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  hintText: '123 Main St, City, ZIP',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating || _submitting ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 16),
                label: const Text('Use my current location'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Apartment #, buzzer, where to meet…',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your address and notes are only shown to the volunteer who accepts.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Request'),
        ),
      ],
    );
  }
}

// ── Recipient: request cards (inside My Claims → Delivery Requests) ─────────

class RecipientRescueRequests extends StatelessWidget {
  final String uid;
  final String? emptyText; // shown when there are no requests at all
  final Stream<List<RescueRequest>>? stream; // injectable for tests

  const RecipientRescueRequests(
      {super.key, required this.uid, this.emptyText, this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RescueRequest>>(
      stream: stream ?? RescueService.recipientRequests(uid),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          if (emptyText == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyText!,
                style: const TextStyle(color: AppColors.textSecondary)),
          );
        }
        return Column(
          children: requests
              .map((r) => RecipientRescueCard(request: r, uid: uid))
              .toList(),
        );
      },
    );
  }
}

class RecipientRescueCard extends StatelessWidget {
  final RescueRequest request;
  final String uid;
  const RecipientRescueCard({super.key, required this.request, required this.uid});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final awaitingMe = r.status == RescueStatus.deliveredPendingRecipient;
    final canCancel =
        r.status == RescueStatus.open || r.status == RescueStatus.claimed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining_outlined,
                    color: RescueStatusChip.color(r.status)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.quantity} × ${r.item}',
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textPrimary)),
                      Text('${r.restaurantName} · #${r.code}'),
                    ],
                  ),
                ),
                RescueStatusChip(status: r.status, forRecipient: true),
              ],
            ),
            if (awaitingMe) ...[
              const SizedBox(height: 8),
              const Text('Your volunteer says the food was delivered.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => runRescueAction(
                          context,
                          () => RescueService.confirmReceived(r.id, uid),
                          'Thanks for confirming!'),
                      child: const Text('Received'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (!await confirmRescueStep(context,
                            'Didn\'t receive it?',
                            'We\'ll flag this delivery for review.')) {
                          return;
                        }
                        if (!context.mounted) return;
                        await runRescueAction(
                            context,
                            () => RescueService.reportNotReceived(r.id, uid),
                            'Reported. Sorry about that.');
                      },
                      child: const Text('Didn\'t receive'),
                    ),
                  ),
                ],
              ),
            ],
            if (canCancel)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (!await confirmRescueStep(context, 'Cancel request?',
                        'The food will go back to the listing for others.')) {
                      return;
                    }
                    if (!context.mounted) return;
                    await runRescueAction(context,
                        () => RescueService.cancel(r.id, uid), 'Request cancelled.');
                  },
                  child: const Text('Cancel request'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Restaurant: pending handoffs (inside each listing card) ─────────────────

class RestaurantRescueHandoffs extends StatelessWidget {
  final String restaurantId;
  final String listingId;
  final Stream<List<RescueRequest>>? stream; // injectable for tests

  const RestaurantRescueHandoffs({
    super.key,
    required this.restaurantId,
    required this.listingId,
    this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RescueRequest>>(
      stream: stream ??
          RescueService.pendingHandoffsForListing(restaurantId, listingId),
      builder: (context, snap) {
        final pending = snap.data ?? [];
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Volunteer pickups to confirm:',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
            ...pending.map((r) => Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Request #${r.code} · ${r.quantity} portion'
                              '${r.quantity == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          RescueStatusChip(status: r.status),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => runRescueAction(
                                context,
                                () => RescueService.confirmHandoff(
                                    r.id, restaurantId),
                                'Handoff confirmed for #${r.code}.'),
                            icon: const Icon(Icons.check,
                                size: 16, color: Colors.green),
                            label: const Text('Confirm handoff',
                                style: TextStyle(color: Colors.green)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => runRescueAction(
                                context,
                                () => RescueService.rejectHandoff(
                                    r.id, restaurantId),
                                'Sent back to the volunteer.'),
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.red),
                            label: const Text('Didn\'t happen',
                                style: TextStyle(color: Colors.red)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
}
