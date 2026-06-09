import 'package:flutter/material.dart';
import '../theme.dart';

const List<String> kAllergens = [
  'Gluten',
  'Dairy',
  'Nuts',
  'Soy',
  'Eggs',
  'Fish',
  'Shellfish',
  'Other',
];

class AllergenChips extends StatelessWidget {
  final List<String> allergens;
  final bool small;

  const AllergenChips({
    super.key,
    required this.allergens,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    if (allergens.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allergens
          .map((a) => Chip(
                label: Text(
                  a,
                  style: TextStyle(
                    fontSize: small ? 10 : 12,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppColors.allergenChip,
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 4 : 6,
                  vertical: 0,
                ),
                visualDensity: VisualDensity.compact,
              ))
          .toList(),
    );
  }
}

class AllergenSelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const AllergenSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: kAllergens.map((a) {
        final isSelected = selected.contains(a);
        return FilterChip(
          label: Text(a),
          selected: isSelected,
          onSelected: (val) {
            final updated = List<String>.from(selected);
            val ? updated.add(a) : updated.remove(a);
            onChanged(updated);
          },
          selectedColor: AppColors.allergenChip.withOpacity(0.8),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
          ),
        );
      }).toList(),
    );
  }
}
