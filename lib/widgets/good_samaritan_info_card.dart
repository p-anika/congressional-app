import 'package:flutter/material.dart';
import '../theme.dart';

class GoodSamaritanInfoCard extends StatelessWidget {
  const GoodSamaritanInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, color: Colors.green.shade800),
                const SizedBox(width: 8),
                Text('You\'re Protected When You Donate',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Under the Bill Emerson Good Samaritan Food Donation Act (42 U.S.C. § 1791), '
              'businesses that donate food in good faith to a nonprofit for distribution to '
              'people in need are protected from civil and criminal liability, as long as the '
              'food wasn\'t donated with gross negligence or intentional misconduct.',
              style: TextStyle(fontSize: 13, color: Colors.green.shade900),
            ),
            const SizedBox(height: 10),
            Text(
              'Food donations may also qualify for an enhanced charitable contribution tax '
              'deduction under IRC §170(e)(3) — often more than the deduction for a straight '
              'cash donation of the same value.',
              style: TextStyle(fontSize: 13, color: Colors.green.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              'This is general information, not legal or tax advice — talk to an attorney or '
              'accountant about your specific situation.',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}