import 'package:flutter/material.dart';

/// Shows a +/- quantity picker dialog. Returns null if cancelled.
Future<int?> showQuantityDialog(
  BuildContext context, {
  required String title,
  required int max,
  String unitLabel = 'portion',
}) {
  int quantity = 1;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  quantity > 1 ? () => setState(() => quantity--) : null,
            ),
            SizedBox(
              width: 90,
              child: Text(
                '$quantity $unitLabel${quantity == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  quantity < max ? () => setState(() => quantity++) : null,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, quantity),
              child: const Text('Confirm')),
        ],
      ),
    ),
  );
}