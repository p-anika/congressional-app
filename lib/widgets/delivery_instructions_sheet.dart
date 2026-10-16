import 'package:flutter/material.dart';
import '../models/rescue_request.dart';
import '../services/location_service.dart';
import '../services/rescue_service.dart';
import '../theme.dart';
import 'rescue_request_widgets.dart';

// Volunteer side of the rescueRequests flow: request cards with
// Accept / Picked up / Delivered, and the "Delivery instructions" sheet.

// ── Lists dropped into the existing Delivery Requests screen ────────────────

class VolunteerActiveRescues extends StatelessWidget {
  final String uid;
  final bool showHeader; // true when there are no older deliveries above
  const VolunteerActiveRescues(
      {super.key, required this.uid, this.showHeader = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RescueRequest>>(
      stream: RescueService.helperRequests(uid),
      builder: (context, snap) {
        final mine = (snap.data ?? []).where((r) => r.isActive).toList();
        if (mine.isEmpty) return const SizedBox.shrink();
        final cards = mine.map((r) => VolunteerRescueCard(request: r, uid: uid));
        if (!showHeader) return Column(children: cards.toList());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Active Deliveries',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...cards,
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class VolunteerOpenRescues extends StatelessWidget {
  final String uid;
  final String? emptyText; // shown when there are no open requests at all
  const VolunteerOpenRescues({super.key, required this.uid, this.emptyText});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RescueRequest>>(
      stream: RescueService.openRequests(),
      builder: (context, snap) {
        final open = (snap.data ?? []).where((r) => r.recipientId != uid).toList();
        if (open.isEmpty) {
          if (emptyText == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText!,
                style: const TextStyle(color: AppColors.textSecondary)),
          );
        }
        return Column(
          children:
              open.map((r) => VolunteerRescueCard(request: r, uid: uid)).toList(),
        );
      },
    );
  }
}

// ── Card ────────────────────────────────────────────────────────────────────

class VolunteerRescueCard extends StatefulWidget {
  final RescueRequest request;
  final String uid;
  // Injectable for tests; default to live Firestore streams.
  final Stream<RescueRequest?>? requestStream;
  final Stream<RescueDropoff?>? dropoffStream;

  const VolunteerRescueCard({
    super.key,
    required this.request,
    required this.uid,
    this.requestStream,
    this.dropoffStream,
  });

  @override
  State<VolunteerRescueCard> createState() => _VolunteerRescueCardState();
}

class _VolunteerRescueCardState extends State<VolunteerRescueCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    await runRescueAction(context, action, success);
    if (mounted) setState(() => _busy = false);
  }

  void _openInstructions() {
    showDeliveryInstructionsSheet(
      context,
      widget.request,
      requestStream: widget.requestStream,
      dropoffStream: widget.dropoffStream,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final uid = widget.uid;
    final isMine = r.helperId == uid;
    final tripMiles = (r.approxLat == null || r.approxLng == null)
        ? null
        : LocationService.distanceInMiles(
            r.restaurantLat, r.restaurantLng, r.approxLat!, r.approxLng!);

    Widget? action;
    if (r.status == RescueStatus.open) {
      action = ElevatedButton(
        onPressed: _busy
            ? null
            : () => _act(() => RescueService.accept(r.id, uid),
                'Accepted. Tap "Delivery instructions" for next steps.'),
        child: const Text('Accept'),
      );
    } else if (isMine && r.status == RescueStatus.claimed) {
      action = ElevatedButton(
        onPressed: _busy
            ? null
            : () async {
                if (!await confirmRescueStep(context, 'Picked up?',
                    'Only tap this once the food is in your hands. ${r.restaurantName} will be asked to confirm.')) {
                  return;
                }
                await _act(() => RescueService.markPickedUp(r.id, uid),
                    'Waiting for ${r.restaurantName} to confirm the handoff.');
              },
        child: const Text('Picked up'),
      );
    } else if (isMine && r.status == RescueStatus.pickedUp) {
      action = ElevatedButton(
        onPressed: _busy
            ? null
            : () async {
                if (!await confirmRescueStep(context, 'Delivered?',
                    'Only tap this once the recipient has the food.')) {
                  return;
                }
                await _act(() => RescueService.markDelivered(r.id, uid),
                    'Thank you! Waiting for the recipient to confirm.');
              },
        child: const Text('Delivered'),
      );
    }

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
                  child: Text('${r.quantity} × ${r.item}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                RescueStatusChip(status: r.status),
              ],
            ),
            Text('Request #${r.code}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            _locationRow(Icons.storefront_outlined, 'Pickup', r.restaurantName,
                r.restaurantAddress, AppColors.primary),
            const SizedBox(height: 6),
            _locationRow(
                Icons.home_outlined,
                'Drop-off',
                'Recipient location',
                isMine
                    ? 'See Delivery instructions for the address'
                    : '${tripMiles == null ? '' : '~${tripMiles.toStringAsFixed(1)} mi from the restaurant · '}'
                        'exact address shown after you accept',
                AppColors.volunteerPrimary),
            if (r.status == RescueStatus.pickupPendingRestaurant) ...[
              const SizedBox(height: 8),
              Text('Waiting for ${r.restaurantName} to confirm the handoff.',
                  style: const TextStyle(fontSize: 12)),
            ],
            if (r.status == RescueStatus.deliveredPendingRecipient) ...[
              const SizedBox(height: 8),
              const Text('Waiting for the recipient to confirm they got it.',
                  style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isMine && r.isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openInstructions,
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('Delivery instructions'),
                    ),
                  ),
                if (isMine && r.isActive && action != null)
                  const SizedBox(width: 8),
                if (action != null) Expanded(child: action),
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

// ── Delivery instructions bottom sheet ──────────────────────────────────────

Future<void> showDeliveryInstructionsSheet(
  BuildContext context,
  RescueRequest request, {
  Stream<RescueRequest?>? requestStream,
  Stream<RescueDropoff?>? dropoffStream,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _LiveDeliveryInstructions(
      initial: request,
      requestStream: requestStream ?? RescueService.requestStream(request.id),
      dropoffStream: dropoffStream ?? RescueService.dropoffStream(request.id),
    ),
  );
}

// Keeps the sheet in sync with live status while it's open.
class _LiveDeliveryInstructions extends StatelessWidget {
  final RescueRequest initial;
  final Stream<RescueRequest?> requestStream;
  final Stream<RescueDropoff?> dropoffStream;
  const _LiveDeliveryInstructions({
    required this.initial,
    required this.requestStream,
    required this.dropoffStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RescueRequest?>(
      stream: requestStream,
      initialData: initial,
      builder: (context, rSnap) {
        final r = rSnap.data ?? initial;
        return StreamBuilder<RescueDropoff?>(
          stream: dropoffStream,
          builder: (context, dSnap) => DeliveryInstructions(
            request: r,
            dropoff: dSnap.data,
            dropoffError: dSnap.hasError,
          ),
        );
      },
    );
  }
}

class DeliveryInstructions extends StatelessWidget {
  final RescueRequest request;
  final RescueDropoff? dropoff;
  final bool dropoffError;
  const DeliveryInstructions({
    super.key,
    required this.request,
    this.dropoff,
    this.dropoffError = false,
  });

  // Index of the step the volunteer is on; 3 means all steps are done.
  int get _current {
    switch (request.status) {
      case RescueStatus.claimed:
        return 0;
      case RescueStatus.pickupPendingRestaurant:
        return 1;
      case RescueStatus.pickedUp:
        return 2;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final d = dropoff;
    final notes = (d == null || d.notes.trim().isEmpty) ? 'none' : d.notes.trim();
    final address = d?.address ??
        (dropoffError
            ? 'the recipient\'s address (couldn\'t load it — try again)'
            : 'the recipient\'s address (loading…)');
    final rejected = r.status == RescueStatus.claimed && r.handoffRejectedAt != null;

    final steps = [
      (
        'Pick up the food',
        'Go to ${r.restaurantName} at ${r.restaurantAddress}. Tell staff '
            'you\'re picking up request #${r.code} (${r.quantity} × ${r.item}). '
            'Tap "Picked up" once you have the food.',
      ),
      (
        'Wait for the restaurant',
        'Waiting for ${r.restaurantName} to confirm the handoff. Ask staff '
            'to tap "Confirm handoff" in their app.',
      ),
      (
        'Deliver',
        'Deliver to $address. Notes: $notes. Tap "Delivered" when done.',
      ),
    ];

    final toRestaurant = r.status == RescueStatus.claimed ||
        r.status == RescueStatus.pickupPendingRestaurant;
    final toRecipient = r.status == RescueStatus.pickedUp && d != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Delivery instructions · #${r.code}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                RescueStatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 12),
            if (rejected)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${r.restaurantName} said the handoff didn\'t happen. Check '
                  'with staff, then tap "Picked up" again once you have the food.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            for (var i = 0; i < steps.length; i++)
              _StepRow(
                number: i + 1,
                title: steps[i].$1,
                text: steps[i].$2,
                done: i < _current,
                current: i == _current,
              ),
            if (r.status == RescueStatus.deliveredPendingRecipient)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    'You marked this delivered. Waiting for the recipient to confirm.',
                    style: TextStyle(color: AppColors.textPrimary)),
              ),
            const SizedBox(height: 12),
            if (toRestaurant)
              ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: Text('Get directions to ${r.restaurantName}'),
                onPressed: () => openRescueDirections(context,
                    lat: r.restaurantLat,
                    lng: r.restaurantLng,
                    address: r.restaurantAddress),
              )
            else if (toRecipient)
              ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('Get directions to recipient'),
                onPressed: () => openRescueDirections(context,
                    lat: d.lat, lng: d.lng, address: d.address),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String title;
  final String text;
  final bool done;
  final bool current;
  const _StepRow({
    required this.number,
    required this.title,
    required this.text,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : current
            ? AppColors.volunteerPrimary
            : AppColors.cardBorder;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: current ? AppColors.volunteerPrimary.withValues(alpha: 0.1) : null,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('$number',
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step $number: $title',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: done ? AppColors.textSecondary : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
